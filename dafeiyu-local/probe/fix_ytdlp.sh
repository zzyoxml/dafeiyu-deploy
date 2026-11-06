#!/bin/bash
set -u

echo "=== 1. 主依赖安装进度（关键）==="
if ps -p 28775 > /dev/null 2>&1; then
  echo "  仍在安装中（PID 28775）"
else
  echo "  进程已结束"
fi
echo "  日志尾部:"
tail -10 /root/sing-install.log 2>/dev/null

echo ""
echo "=== 2. torch 是否装好 ==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "import torch; print('  torch', torch.__version__)" 2>&1 | tail -2

echo ""
echo "=== 3. 修 yt-dlp（用镜像重装）==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -m pip install \
  --index-url https://pypi.tuna.tsinghua.edu.cn/simple \
  --force-reinstall --no-deps yt-dlp 2>&1 | tail -4
echo ""
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "import yt_dlp; print('  yt-dlp', yt_dlp.version.__version__)" 2>&1 | tail -2
