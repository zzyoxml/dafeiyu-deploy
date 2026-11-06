#!/usr/bin/env bash
# 大肥鱼 QQ 机器人 · 统一执行入口
#
# 用法（Windows Git Bash 里）:
#   bash /d/xml/dafeiyu/run.sh <脚本名> [参数...]
#
# 所有 WSL 侧脚本都通过这里跑：
#   - 统一 base64 传输，避开路径里的中文与引号问题
#   - 输出统一写到 /mnt/d/xml/dafeiyu/out/<名字>.txt
#   - 计划任务也调用这个入口，不再弹 PowerShell 窗口

set -e

WIN_ROOT="/d/xml/dafeiyu"
WSL_ROOT="/mnt/d/xml/dafeiyu"

SCRIPT_DIR="$WIN_ROOT/dafeiyu-local"
OUT_DIR="$WIN_ROOT/out"
mkdir -p "$OUT_DIR"

name="${1:-help}"
shift || true

case "$name" in
  help|-h|--help)
    echo "用法: bash run.sh <脚本名>"
    echo ""
    echo "可用脚本:"
    ls "$SCRIPT_DIR"/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//' | sed 's/^/  /'
    exit 0
    ;;
esac

src="$SCRIPT_DIR/$name.sh"
if [ ! -f "$src" ]; then
  echo "找不到脚本: $src" >&2
  exit 1
fi

out_file="$OUT_DIR/$name.txt"

# 读入脚本内容 → base64 → 送进 WSL 执行
payload=$(base64 -w0 "$src")
extra=""
if [ $# -gt 0 ]; then
  extra="$(printf ' %s' "$@")"
fi

wsl -d Ubuntu-24.04 -u root -- bash -c "
  echo $payload | base64 -d > /tmp/dfy_$name.sh
  bash /tmp/dfy_$name.sh $extra
" 2>&1 | tee "$out_file"

echo ""
echo "--- 输出已保存: $out_file ---"