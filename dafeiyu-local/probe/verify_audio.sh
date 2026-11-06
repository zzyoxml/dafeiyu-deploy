#!/bin/bash
set -u
echo "=== 1. 产物音频信息 ==="
docker exec astrbot sh -c "ffprobe -v error -show_entries format=duration,bit_rate,size -show_entries stream=codec_name,channels,sample_rate -of default=noprint_wrappers=1 /AstrBot/data/audio/e2e-test-20261030122303.mp3 2>&1"

echo ""
echo "=== 2. 音量检查（确认不是静音）==="
docker exec astrbot sh -c "ffmpeg -hide_banner -i /AstrBot/data/audio/e2e-test-20261030122303.mp3 -af volumedetect -f null - 2>&1 | grep -E 'mean_volume|max_volume'"

echo ""
echo "=== 3. 复制到 Windows 试听 ==="
cp /opt/dafeiyu/data/astrbot/audio/e2e-test-20261030122303.mp3 /mnt/d/xml/dafeiyu/sing-test-preview.mp3 2>/dev/null
ls -lh /mnt/d/xml/dafeiyu/sing-test-preview.mp3 2>/dev/null || echo "  复制失败"
