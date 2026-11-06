#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 同步插件三个位置 ==="
SRC=/opt/dafeiyu/data/astrbot/plugins/dsh-stt-clean
mkdir -p /opt/dafeiyu/repo/plugins/dsh-stt-clean
cp "$SRC/main.py" /opt/dafeiyu/repo/plugins/dsh-stt-clean/main.py
cp "$SRC/metadata.yaml" /opt/dafeiyu/repo/plugins/dsh-stt-clean/metadata.yaml
echo "  repo/plugins/dsh-stt-clean 已同步"

echo ""
echo "=== 2. 检查 .gitignore 会不会挡住 stt-models ==="
grep -nE "stt-models|models" .gitignore | head -6 | sed 's/^/  /'

echo ""
echo "=== 3. 当前改动 ==="
git status --porcelain | head -20 | sed 's/^/  /'
echo "  总计: $(git status --porcelain | wc -l)"
