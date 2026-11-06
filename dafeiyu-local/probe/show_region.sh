#!/bin/bash
set -u
P=/opt/dafeiyu/data/astrbot/plugins/dsh-selfguard/main.py

echo "=== 1. 备份 ==="
cp "$P" "${P}.bak-before-silent-$(date +%H%M%S)"
echo "  已备份"

echo ""
echo "=== 2. 改造前 380-406 行 ==="
sed -n '380,406p' "$P"
