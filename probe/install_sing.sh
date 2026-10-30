#!/bin/bash
set -u

echo "=== 1. 安装进度 ==="
tail -4 /root/sing-install.log 2>/dev/null || echo "  日志不存在"

echo ""
echo "=== 2. 安装 dsh-sing 插件 ==="
mkdir -p /opt/dafeiyu/data/astrbot/plugins/dsh-sing
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
cp <PROBE_DIR>/dsh-sing/metadata.yaml \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/metadata.yaml
echo "  已复制文件"

echo ""
echo "=== 3. 语法检查 ==="
cat > /tmp/syntax_check.py <<'PYEOF'
import ast
p = "/AstrBot/data/plugins/dsh-sing/main.py"
try:
    ast.parse(open(p, encoding="utf-8").read())
    print("  语法 OK")
except SyntaxError as e:
    print(f"  语法错误: line {e.lineno}: {e.msg}")
    raise SystemExit(1)
PYEOF
docker cp /tmp/syntax_check.py astrbot:/tmp/syntax_check.py
docker exec astrbot python3 /tmp/syntax_check.py 2>&1

echo ""
echo "=== 4. 确保 yt-dlp 存在 ==="
if docker exec astrbot test -x /AstrBot/data/sing/venv/bin/yt-dlp 2>/dev/null; then
  echo "  venv 里已有 yt-dlp"
else
  echo "  正在安装 yt-dlp..."
  docker exec astrbot /AstrBot/data/sing/venv/bin/python -m pip install -q yt-dlp 2>&1 | tail -2
  docker exec astrbot sh -c "ls -la /AstrBot/data/sing/venv/bin/yt-dlp 2>/dev/null" || echo "  ⚠ yt-dlp 仍未就绪"
fi

echo ""
echo "=== 5. 容器内 ffmpeg ==="
docker exec astrbot sh -c "which ffmpeg && ffmpeg -version 2>/dev/null | head -1"

echo ""
echo "=== 6. 容器内能看到 sing 目录吗 ==="
docker exec astrbot sh -c "ls /AstrBot/data/sing/ | head -8"
