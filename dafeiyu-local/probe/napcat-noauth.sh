#!/bin/bash
# 让 NapCat WebUI 永久无密码：每次容器启动后自动给 napcat.mjs 打补丁
# 放在 /opt/dafeiyu/data/napcat/napcat-config/ 下（该目录挂载到 /app/napcat/config，持久）
set -u

PATCH="/app/napcat/config/patch_noauth.py"
TARGET="/app/napcat/napcat.mjs"

# 等 napcat.mjs 被 entrypoint 解包出来
for i in $(seq 1 60); do
  [ -f "$TARGET" ] && break
  sleep 2
done

[ -f "$TARGET" ] || { echo "[noauth] $TARGET 不存在，跳过"; exit 0; }

# 已打过补丁就退出（幂等）
if grep -qa "PATCHED: WebUI 已设为无密码" "$TARGET" 2>/dev/null; then
  echo "[noauth] 补丁已存在，无需处理"
  exit 0
fi

[ -f "$PATCH" ] || { echo "[noauth] $PATCH 缺失"; exit 0; }

echo "[noauth] 正在打无密码补丁..."
python3 "$PATCH" 2>&1
echo "[noauth] 完成"
