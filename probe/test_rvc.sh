#!/bin/bash
set -u
SING=/AstrBot/data/sing

echo "=== 1. 预下载 demucs htdemucs 模型（约 80MB）==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c \
  "from demucs.pretrained import get_model; m = get_model('htdemucs'); print('  htdemucs OK:', sum(p.numel() for p in m.parameters()))" 2>&1 | tail -5

echo ""
echo "=== 2. 检查 cover.py 依赖路径 ==="
docker exec astrbot sh -c "ls -la /AstrBot/data/sing/model/liuying.pth"
docker exec astrbot sh -c "ls -la /AstrBot/data/sing/rvc_cli/rvc/models/predictors/rmvpe.pt 2>/dev/null || echo '  ⚠ rmvpe 不在预期位置'"
docker exec astrbot sh -c "ls /AstrBot/data/sing/rvc/models/embedders/contentvec/"

echo ""
echo "=== 3. 生成 3 秒测试音频 ==="
docker exec astrbot sh -c "ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=440:duration=3' -ar 44100 -ac 1 /tmp/test-tone.wav && ls -la /tmp/test-tone.wav"

echo ""
echo "=== 4. 跑 cover.py（RVC 转换测试，CPU 模式）==="
echo "  这步会加载 hubert + rmvpe + liuying 模型，首次较慢"
timeout 900 docker exec astrbot /AstrBot/data/sing/venv/bin/python \
  /AstrBot/data/sing/cover.py /tmp/test-tone.wav /tmp/test-rvc-out.wav 0 rmvpe 2>&1 | tail -25

echo ""
echo "=== 5. 检查输出 ==="
docker exec astrbot sh -c "ls -la /tmp/test-rvc-out.wav 2>/dev/null || echo '  ❌ 没有输出文件'"
