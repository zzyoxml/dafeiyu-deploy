#!/bin/bash
set -u
BL=/opt/dafeiyu/data/astrbot/sing/venv/bin
echo "=== 1. venv/bin 内容 ==="
ls -la "$BL" 2>/dev/null | head -12 | sed 's/^/  /'

echo ""
echo "=== 2. python 软链指向 ==="
readlink -f "$BL/python" 2>/dev/null | sed 's/^/  指向: /'
[ -L "$BL/python" ] && echo "  是软链"

echo ""
echo "=== 3. 从容器内直接调用 ==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "
import sys
print('  venv python 可用:', sys.executable)
import torch
print('  torch:', torch.__version__)
" 2>&1 | tail -5

echo ""
echo "=== 4. 从 WSL 宿主直接调用 ==="
"$BL/python" -c "print('  host 可见')" 2>&1 | tail -3

echo ""
echo "=== 5. demucs 命令 ==="
ls -la "$BL/demucs" 2>/dev/null | sed 's/^/  /' || echo "  无 demucs 入口"
</script>
</invoke>
