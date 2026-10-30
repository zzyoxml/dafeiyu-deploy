#!/bin/bash
# NapCat WebUI 无密码：启动包装器
#
# 为什么需要它：
#   /app/napcat 不在挂载卷里（在容器可写层），docker compose up --force-recreate
#   或 down 之后补丁会丢失。这个脚本放在持久挂载卷 /app/napcat/config 下，
#   由 compose 的 entrypoint 覆盖来调用，每次启动都保证补丁还在。
#
# 为什么补丁放后台：
#   原 entrypoint.sh 末尾是 `gosu napcat /opt/QQ/qq`（前台阻塞），
#   解包 napcat.mjs 之后它还要做 cgroup 伪造、/etc/hosts 挂载、chown -R /app
#   一大段准备工作才真正拉起 QQ，时间差足够补丁跑完。
set -u

PATCH_PY="/app/napcat/config/patch_noauth.py"
TARGET="/app/napcat/napcat.mjs"

(
  for _ in $(seq 1 900); do          # 最多等 180 秒
    if [ -f "$TARGET" ]; then
      if grep -qa "PATCHED: WebUI 已设为无密码" "$TARGET" 2>/dev/null; then
        echo "[noauth] 补丁已存在，跳过"
        exit 0
      fi
      if [ -f "$PATCH_PY" ]; then
        echo "[noauth] 检测到未打补丁的 napcat.mjs，正在应用无密码补丁..."
        python3 "$PATCH_PY" 2>&1 || echo "[noauth] 打补丁失败"
        exit 0
      fi
      echo "[noauth] 找不到 $PATCH_PY，跳过"
      exit 0
    fi
    sleep 0.2
  done
  echo "[noauth] 等待 napcat.mjs 超时，未打补丁"
) &

cd /app || exit 1
exec bash /app/entrypoint.sh
