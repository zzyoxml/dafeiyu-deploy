#!/usr/bin/env bash
# 持续把 NapCat 最新的二维码同步到 Windows，保证你打开时永远是新鲜的
set -u
DST="<WIN_MOUNT>/xml/dafeiyu/qrcode.png"
DST2="<WIN_MOUNT>/xml/dafeiyu/扫码登录.png"

echo "[qr-sync] 启动，每 5 秒同步一次最新二维码"
echo "[qr-sync] 目标: $DST"

last=""
n=0
while true; do
  if docker exec napcat sh -c "test -f /app/napcat/cache/qrcode.png" 2>/dev/null; then
    # 先拷到临时文件再改名，避免读到写了一半的文件
    if docker cp napcat:/app/napcat/cache/qrcode.png "${DST}.tmp" 2>/dev/null; then
      sz=$(stat -c%s "${DST}.tmp" 2>/dev/null || echo 0)
      if [ "$sz" -gt 300 ]; then
        mv -f "${DST}.tmp" "$DST"
        cp -f "$DST" "$DST2" 2>/dev/null || true
        # 内容变了就打一行，方便看是否在刷新
        cur=$(md5sum "$DST" 2>/dev/null | cut -d' ' -f1)
        if [ "$cur" != "$last" ]; then
          n=$((n+1))
          echo "[qr-sync] $(date '+%H:%M:%S') 已更新第 ${n} 张 (${sz}B)"
          last="$cur"
        fi
      fi
    fi
  fi

  # 已登录就停
  if docker logs napcat --since 10s 2>&1 | grep -qaE '登录成功|Login Success|账号已上线'; then
    echo "[qr-sync] 检测到登录成功，退出"
    exit 0
  fi

  sleep 5
done
