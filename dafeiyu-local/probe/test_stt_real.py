"""实测 SenseVoice ONNX 中文识别。"""
import os
import subprocess
import tempfile
import time

MP = "/AstrBot/data/stt-models/models/iic--SenseVoiceSmall-onnx/snapshots/master"
print(f"模型目录: {MP}")
print(f"model_quant.onnx: {os.path.getsize(MP + '/model_quant.onnx')//1048576}MB")
print()

print("=== 1. 加载模型 ===")
t0 = time.time()
from funasr_onnx import SenseVoiceSmall
from funasr_onnx.utils.postprocess_utils import rich_transcription_postprocess

m = SenseVoiceSmall(MP, quantize=True, batch_size=1)
print(f"  加载 {time.time()-t0:.1f}s")
print()

print("=== 2. 造测试音频（用 Edge TTS 生成已知文本）===")
tmp = "/tmp/stt-test"
os.makedirs(tmp, exist_ok=True)
samples = [
    ("糖葫芦或者桂花糖藕", "/tmp/stt-test/a.mp3"),
    ("今天下午两点多，这时候就想来点甜的", "/tmp/stt-test/b.mp3"),
]

scr = tmp + "/gen.py"
open(scr, "w").write(
    "import asyncio,sys\nimport edge_tts\n"
    "async def m():\n"
    "    await edge_tts.Communicate(sys.argv[2],'zh-CN-XiaoxiaoNeural').save(sys.argv[1])\n"
    "asyncio.run(m())\n"
)
for text, path in samples:
    r = subprocess.run(
        ["/AstrBot/data/sing/venv/bin/python", scr, path, text],
        capture_output=True, text=True)
    if os.path.exists(path) and os.path.getsize(path) > 512:
        # 转成 wav（模型要 wav）
        wav = path.replace(".mp3", ".wav")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path,
                        "-ar", "16000", "-ac", "1", wav], check=False)
        print(f"  生成: {text!r} -> {os.path.getsize(wav)//1024}KB wav")
    else:
        print(f"  生成失败: {text!r} {r.stderr[:100]}")

print()
print("=== 3. 识别 ===")
for text, path in samples:
    wav = path.replace(".mp3", ".wav")
    if not os.path.exists(wav):
        print(f"  跳过（无 wav）: {text!r}")
        continue
    t0 = time.time()
    try:
        res = m(wav, language="auto", use_itn=True, batch_size=1)
        dt = time.time() - t0
        raw = res[0]["text"] if isinstance(res, list) else str(res)
        clean = rich_transcription_postprocess(raw)
        print(f"  原文: {text}")
        print(f"  识别: {clean}   ({dt:.2f}s)")
        ok = text.replace("，", "").replace("、", "") in clean.replace("，", "")
        print(f"  匹配: {'✅' if ok else '⚠ 有差异'}")
        print()
    except Exception as e:
        print(f"  ❌ {type(e).__name__}: {e}")
        print()
