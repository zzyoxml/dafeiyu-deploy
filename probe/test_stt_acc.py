#!/bin/bash
# STT 准确度回归：8 句已知文本（Edge TTS 合成）→ 识别 → 逐字比对
#
# 设计要点：
#  - 用 Edge TTS 现造音频，文本已知，才能算「完全一致」的比例
#  - 比对前归一化标点，因为 SenseVoice 会自己加标点/emoji
#  - 实测基线：5/8 完全一致，其余是标点或同音字差异（小鲸鱼→小金鱼）
"""多点实测 SenseVoice 中文识别准确度与速度。"""
import os
import subprocess
import time

MP = "/AstrBot/data/stt-models/models/iic--SenseVoiceSmall-onnx/snapshots/master"
from funasr_onnx import SenseVoiceSmall
from funasr_onnx.utils.postprocess_utils import rich_transcription_postprocess

t0 = time.time()
m = SenseVoiceSmall(MP, quantize=True, batch_size=1)
print(f"模型加载 {time.time()-t0:.1f}s\n")

# 生成 8 条已知文本的语音
SAMPLES = [
    "糖葫芦或者桂花糖藕",
    "今天下午两点多，这时候就想来点甜的",
    "小鲸鱼你听得见我说话吗",
    "这段我这边听不清你说的是啥",
    "明天下午三点开会别忘了",
    "哈哈哈哈这也太好笑了吧",
    "你是不是又在偷懒了",
    "来点桂花糕怎么样",
]

tmp = "/tmp/stt-test2"
os.makedirs(tmp, exist_ok=True)
gen = tmp + "/gen.py"
open(gen, "w").write(
    "import asyncio,sys\nimport edge_tts\n"
    "async def m():\n"
    "    await edge_tts.Communicate(sys.argv[2],'zh-CN-XiaoxiaoNeural').save(sys.argv[1])\n"
    "asyncio.run(m())\n"
)

print("=== 生成测试音频 ===")
paths = []
for i, text in enumerate(SAMPLES):
    mp3 = f"{tmp}/{i}.mp3"
    wav = f"{tmp}/{i}.wav"
    subprocess.run(["/AstrBot/data/sing/venv/bin/python", gen, mp3, text],
                   capture_output=True, text=True)
    if os.path.exists(mp3) and os.path.getsize(mp3) > 512:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mp3,
                        "-ar", "16000", "-ac", "1", wav], check=False)
        paths.append((text, wav))
print(f"  成功 {len(paths)}/{len(SAMPLES)}\n")

print("=== 识别结果 ===")
ok_n = 0
tot_dt = 0
for text, wav in paths:
    t0 = time.time()
    try:
        r = m(wav, language="auto", use_itn=True, batch_size=1)
        dt = time.time() - t0
        tot_dt += dt
        raw = r[0] if isinstance(r, list) and r else str(r)
        clean = rich_transcription_postprocess(raw) if "<|" in str(raw) else str(raw)
        # 去掉标点后比对
        import re
        norm = lambda s: re.sub(r"[，。？！、,.?!\s]", "", s)
        match = norm(text) == norm(clean)
        ok_n += match
        print(f"  原文: {text}")
        print(f"  识别: {clean}")
        print(f"  {'✅ 完全一致' if match else '⚠ 有差异'}  ({dt:.2f}s)")
        print()
    except Exception as e:
        print(f"  ❌ {type(e).__name__}: {e}\n")

print(f"=== 汇总 ===")
print(f"  完全一致: {ok_n}/{len(paths)}  ({ok_n/len(paths)*100:.0f}%)")
print(f"  平均耗时: {tot_dt/max(len(paths),1):.2f}s / 句")
print(f"  模型加载: 首次 8.6s，之后常驻内存")

