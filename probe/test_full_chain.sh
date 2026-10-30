#!/bin/bash
set -u
echo "=== 完整 AI 翻唱链路测试（30 秒片段）==="
echo ""

echo "--- [1/4] 截取 30 秒 ---"
docker exec astrbot sh -c "rm -f /tmp/clip30.wav && ffmpeg -hide_banner -loglevel error -y -ss 30 -t 30 -i /tmp/dl-real.mp3 -ar 44100 -ac 2 /tmp/clip30.wav && ls -la /tmp/clip30.wav"

echo ""
echo "--- [2/4] demucs 分离人声（CPU，可能要 1-3 分钟）---"
START=$(date +%s)
docker exec astrbot sh -c "cd /tmp && rm -rf demucs-out && /AstrBot/data/sing/venv/bin/python -m demucs -n htdemucs --two-stems=vocals -d cpu -o /tmp/demucs-out /tmp/clip30.wav 2>&1 | tail -6"
END=$(date +%s)
echo "  耗时: $((END-START)) 秒"
docker exec astrbot sh -c "ls -la /tmp/demucs-out/htdemucs/clip30/ 2>/dev/null || echo '  ❌ 分离失败'"

echo ""
echo "--- [3/4] RVC 换流萤音色 ---"
VOCALS=/tmp/demucs-out/htdemucs/clip30/vocals.wav
if docker exec astrbot test -f "$VOCALS"; then
  START=$(date +%s)
  timeout 1800 docker exec astrbot /AstrBot/data/sing/venv/bin/python \
    /AstrBot/data/sing/cover.py "$VOCALS" /tmp/vocals-ai.wav 0 rmvpe 2>&1 | tail -8
  END=$(date +%s)
  echo "  耗时: $((END-START)) 秒"
  docker exec astrbot sh -c "ls -la /tmp/vocals-ai.wav 2>/dev/null || echo '  ❌ RVC 失败'"
else
  echo "  跳过：没人声文件"
fi

echo ""
echo "--- [4/4] 混回伴奏 ---"
if docker exec astrbot test -f /tmp/vocals-ai.wav; then
  docker exec astrbot sh -c "ffmpeg -hide_banner -loglevel error -y -i /tmp/vocals-ai.wav -i /tmp/demucs-out/htdemucs/clip30/no_vocals.wav -filter_complex '[0:a]volume=1.0[v];[1:a]volume=0.72[i];[v][i]amix=inputs=2:duration=longest:dropout_transition=0:normalize=0[out]' -map '[out]' -t 30 -ar 44100 -ac 2 -b:a 192k /tmp/sing-final.mp3 2>&1"
  docker exec astrbot sh -c "ls -lh /tmp/sing-final.mp3 2>/dev/null && ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 /tmp/sing-final.mp3"
fi
