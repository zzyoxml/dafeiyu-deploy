#!/bin/bash
set -u
echo "=== 1. sing/venv 里有什么相关包 ==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "
import importlib.util as u
for m in ['funasr_onnx','funasr','whisper','torch','torchaudio','onnxruntime','numpy','soundfile','librosa']:
    print(f'  {m:14} {\"✅\" if u.find_spec(m) else \"❌\"}')
" 2>&1 | tail -10

echo ""
echo "=== 2. 容器磁盘空间 ==="
df -h /opt/dafeiyu 2>/dev/null | tail -1 | sed 's/^/  /'
docker exec astrbot df -h /AstrBot 2>/dev/null | tail -1 | sed 's/^/  /'

echo ""
echo "=== 3. 音频格式处理能力（关键：QQ 是 .amr / silk）==="
docker exec astrbot sh -c "which ffmpeg && ffmpeg -version 2>&1 | head -2" 2>&1 | head -3
echo "  ffmpeg 在 sing/venv:"
docker exec astrbot sh -c "ls /AstrBot/data/sing/venv/bin/ffmpeg 2>/dev/null || echo '   无'" 2>&1

echo ""
echo "=== 4. MediaResolver 怎么转 amr ==="
docker exec astrbot sh -c "grep -n 'amr\|silk\|target_format\|ffmpeg' /AstrBot/astrbot/core/utils/media_utils.py 2>//dev/null | head -10" 2>&1 || \
docker exec astrbot sh -c "grep -n 'amr\|silk\|target_format\|ffmpeg' /AstrBot/astrbot/core/utils/media_utils.py 2>/dev/null | head -10" 2>&1

echo ""
echo "=== 5. 现有 STT 相关 pip 安装可行性（测网络）==="
docker exec astrbot sh -c "pip download funasr-onnx -d /tmp/x --no-deps -q 2>&1 | head -3" 2>&1 | head -5
