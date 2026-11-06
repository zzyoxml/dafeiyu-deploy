#!/usr/bin/env bash
# 刷新二维码并立刻导出（避免人工延迟导致过期）
set -u
OUT="/mnt/d/xml/dafeiyu/qrcode.png"

echo "=== 删除旧二维码 ==="
docker exec napcat sh -c "rm -f /app/napcat/cache/qrcode.png" 2>/dev/null

echo "=== 重启 napcat ==="
docker restart napcat >/dev/null 2>&1

echo "=== 轮询等待新二维码（最多 60 秒）==="
for i in $(seq 1 30); do
  sleep 2
  if docker exec napcat sh -c "test -f /app/napcat/cache/qrcode.png" 2>/dev/null; then
    echo "  ${i}0% 秒时出现"
    break
  fi
done

echo ""
echo "=== 立刻导出 ==="
docker cp napcat:/app/napcat/cache/qrcode.png "$OUT" 2>&1
ls -la "$OUT" 2>&1
echo "  文件大小: $(stat -c%s "$OUT" 2>/dev/null || echo 0) 字节"

echo ""
echo "=== 获取解码 URL（备用）==="
docker logs napcat --since 90s 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -aoE 'https://txz\.qq\.com/p\?k=[A-Za-z0-9_=-]+&f=[0-9]+' | tail -1

echo ""
echo "=== 当前登录状态 ==="
docker logs napcat --since 90s 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -aE '等待扫码|二维码|Login|登录成功|在线' | tail -6
