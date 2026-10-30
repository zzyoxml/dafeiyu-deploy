#!/usr/bin/env bash
# 二维码保活：码超过 80 秒没变就强制刷新（重启 napcat），保证 Windows 侧永远是新鲜码
# 登录成功后自动退出
set -u
DST="<WIN_MOUNT>/xml/dafeiyu/qrcode.png"
DST2="<WIN_MOUNT>/xml/dafeiyu/扫码登录.png"
CONTAINER_QR="/app/napcat/cache/qrcode.png"

echo "[qr-keep] 启动：码超过 80 秒未变就自动换新码"

last_md5=""
last_change=$(date +%s)
n=0

while true; do
  # 登录成功就收工
  if docker logs napcat --since 15s 2>&1 | grep -qaE "登录成功|Login Success|账号已上线|扫码成功"; then
    echo "[qr-keep] 登录成功，退出"
    exit 0
  fi

  cur_md5=$(docker exec napcat md5sum "$CONTAINER_QR" 2>/dev/null | cut -d' ' -f1)
  now=$(date +%s)

  if [ -n "$cur_md5" ] && [ "$cur_md5" != "$last_md5" ]; then
    # 新码：立即同步到 Windows
    docker cp napcat:"$CONTAINER_QR" "${DST}.tmp" >/dev/null 2>&1
    sz=$(stat -c%s "${DST}.tmp" 2>/dev/null || echo 0)
    if [ "$sz" -gt 300 ]; then
      mv -f "${DST}.tmp" "$DST"
      cp -f "$DST" "$DST2" 2>/dev/null || true
      n=$((n+1))
      echo "[qr-keep] $(date '+%H:%M:%S') 新码 #$n 已同步"
      last_md5="$cur_md5"
      last_change=$now
    fi
  elif [ -n "$cur_md5" ] && [ $((now - last_change)) -ge 80 ]; then
    # 码太旧：强制刷新（重启 napcat 触发新码）
    echo "[qr-keep] $(date '+%H:%M:%S') 码已 ${now} - ${last_change} 秒未变，强制换新码"
    last_change=$now   # 先重置，避免重启期间反复触发
    docker restart napcat >/dev/null 2>&1
    sleep 20
    last_md5=""        # 重启后强制重新同步
  fi

  sleep 5
done
