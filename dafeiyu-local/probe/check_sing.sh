#!/bin/bash
set -u
echo "=== 1. sing 目录结构 ==="
ls -la /opt/dafeiyu/data/astrbot/sing/ 2>/dev/null | head -15 | sed 's/^/  /'

echo ""
echo "=== 2. 关键路径是否存在 ==="
for p in \
  /opt/dafeiyu/data/astrbot/sing/venv/bin/python \
  /opt/dafeiyu/data/astrbot/sing/venv/bin/pip \
  /opt/dafeiyu/data/astrbot/sing/rvc \
  /opt/dafeiyu/data/astrbot/sing/model \
  /opt/dafeiyu/data/astrbot/sing/song-cache ; do
  if [ -e "$p" ]; then
    SZ=$(du -sh "$p" 2>/dev/null | cut -f1)
    echo "  ✅ $p  ($SZ)"
  else
    echo "  ❌ 缺失 $p"
  fi
done

echo ""
echo "=== 3. venv 内 torch/demucs 是否完好 ==="
V=/opt/dafeiyu/data/astrbot/sing/venv/bin/python
if [ -x "$V" ]; then
  docker exec astrbot $V -c "
import torch, demucs, librosa
print('  torch', torch.__version__)
print('  demucs', demucs.__version__)
print('  librosa', librosa.__version__)
" 2>&1 | tail -4
else
  echo "  ❌ venv python 不可执行"
fi

echo ""
echo "=== 4. 流萤模型 ==="
find /opt/dafeiyu/data/astrbot/sing -name "*.pth" -o -name "*.pt" 2>/dev/null | head -5 | sed 's/^/  /'

echo ""
echo "=== 5. 歌单缓存 ==="
ls /opt/dafeiyu/data/astrbot/sing/song-cache/*.mp3 2>/dev/null | wc -l | xargs -I{} echo "  {} 首已缓存"
