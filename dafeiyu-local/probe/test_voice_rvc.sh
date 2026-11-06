#!/bin/bash
set -u
echo "=== 测试：Edge TTS 生成 → RVC 换成流萤音色（说话场景）==="
cat > /tmp/test_voice_rvc.py <<'PYEOF'
import asyncio, os, subprocess, sys

VENV_PY = "/AstrBot/data/sing/venv/bin/python"
COVER = "/AstrBot/data/sing/cover.py"
TXT = "你好呀，我是小鲸鱼，今天也要开开心心的"

async def main():
    import edge_tts
    raw = "/tmp/tts-raw.mp3"
    print(f"  [1] Edge TTS 合成：{TXT}")
    c = edge_tts.Communicate(TXT, "zh-CN-XiaoxiaoNeural", rate="-5%", pitch="+2Hz")
    await c.save(raw)
    print(f"      生成 {os.path.getsize(raw)} bytes")

    # 说话场景不需要分离伴奏（Edge 输出是纯净人声），直接转 wav 送 RVC
    wav = "/tmp/tts-raw.wav"
    print("  [2] 转 wav (40k，匹配 RVC 期望采样率)")
    subprocess.run(
        ["ffmpeg","-hide_banner","-loglevel","error","-y","-i",raw,
         "-ar","40000","-ac","1",wav], check=True)
    print(f"      生成 {os.path.getsize(wav)} bytes")

    out = "/tmp/tts-liuying.wav"
    print("  [3] RVC 换成流萤音色（CPU）")
    r = subprocess.run([VENV_PY, COVER, wav, out, "0", "rmvpe"],
                       capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        print("      ❌ 失败:")
        print("\n".join(r.stderr.strip().splitlines()[-8:]))
        return
    print(f"      成功 {os.path.getsize(out)} bytes")

    final = "/tmp/tts-liuying.mp3"
    subprocess.run(
        ["ffmpeg","-hide_banner","-loglevel","error","-y","-i",out,
         "-ar","44100","-ac","2","-b:a","128k",final], check=True)
    print(f"  [4] 输出 mp3: {os.path.getsize(final)} bytes")

    # 验证
    probe = subprocess.run(
        ["ffprobe","-v","error","-show_entries","format=duration",
         "-of","default=noprint_wrappers=1:nokey=1", final],
        capture_output=True, text=True)
    print(f"  时长: {probe.stdout.strip()}s")
    os.system(f"cp {final} /AstrBot/data/audio/voice-liuying-test.mp3")
    print("  ✅ 完成，已复制到 audio/")

asyncio.run(main())
PYEOF
docker cp /tmp/test_voice_rvc.py astrbot:/tmp/test_voice_rvc.py
timeout 900 docker exec astrbot python3 /tmp/test_voice_rvc.py 2>&1 | tail -20
