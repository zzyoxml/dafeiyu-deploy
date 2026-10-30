#!/bin/bash
set -u
echo "=== 用真实搜索结果测试下载 ==="
# BV15kHA6oEjp 是搜索结果第3条《【Hi-Res】夜曲-周杰伦》
docker exec astrbot sh -c "cd /tmp && rm -f dl-real* && /AstrBot/data/sing/venv/bin/yt-dlp --no-warnings -f 'bestaudio/best' -x --audio-format mp3 --audio-quality 5 -o 'dl-real.%(ext)s' --no-playlist 'https://www.bilibili.com/video/BV15kHA6oEjp' 2>&1 | tail -12"

echo ""
echo "=== 下载结果 ==="
docker exec astrbot sh -c "ls -lh /tmp/dl-real* 2>/dev/null || echo '  ❌ 无文件'"

echo ""
echo "=== 音频时长 ==="
docker exec astrbot sh -c "ffprobe -v error -show_entries format=duration,size -of default=noprint_wrappers=1 /tmp/dl-real.mp3 2>/dev/null || echo '  无法读取'"
