#!/bin/bash
set -u
echo "=== 1. 重启加载最新插件 ==="
cd /opt/dafeiyu
docker compose restart astrbot 2>&1 | tail -1
for i in $(seq 1 30); do
  sleep 5
  h=$(docker inspect astrbot --format "{{.State.Health.Status}}" 2>/dev/null | tr -d "\r\n ")
  if [ "$h" = "healthy" ]; then echo "  ✅ 第 $((i*5))s healthy"; break; fi
done

echo ""
echo "=== 2. 确认加载成功 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "dsh-sing" | tail -4

echo ""
echo "=== 3. QQ 在线状态 ==="
docker exec napcat sh -c "cat /app/napcat/config/napcat.json 2>/dev/null | head -3" 2>/dev/null | head -3
curl -s -m 10 -X POST "http://127.0.0.1:3000/get_login_info" \
  -H "Authorization: Bearer <你的OneBot_Token>" \
  -H "Content-Type: application/json" -d '{}' 2>/dev/null | head -c 300 || \
  echo "  (OneBot HTTP 未开，走 WS)"

echo ""
echo "=== 4. 网络连通性（QQ 侧）==="
docker exec astrbot sh -c "curl -s -m 8 -o /dev/null -w '  bilibili: %{http_code}\n' https://api.bilibili.com/x/web-interface/search/type?search_type=video\&keyword=test 2>/dev/null || echo '  bilibili 不通'"
