#!/bin/bash
set -u
echo "=== 1. dsh-reply-guard 是否加载 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "reply-guard" | tail -5 || echo "  完全没有日志"

echo ""
echo "=== 2. 当前加载的插件（大肥鱼自建）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Plugin .* by 大肥鱼" | sed 's/.*Plugin /  /' | cut -c1-55 | tail -25

echo ""
echo "=== 3. 插件目录 ==="
ls -la /opt/dafeiyu/data/astrbot/plugins/dsh-reply-guard/ 2>&1 | sed 's/^/  /'

echo ""
echo "=== 4. 重载尝试 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-reply-guard"}' 2>&1 | head -c 200
echo ""
sleep 3
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "reply-guard" | tail -4
