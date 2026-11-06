#!/bin/bash
set -u
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
echo "=== 1. 热重载 dsh-reply-guard ==="
curl -s -m 30 -X POST "http://127.0.0.1:6185/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-reply-guard"}' 2>&1 | head -c 200
echo ""

echo "=== 2. 热重载 dsh-sing（缓存版）==="
curl -s -m 30 -X POST "http://127.0.0.1:6185/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 200
echo ""
sleep 4

echo "=== 3. 加载结果 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "\[guard\] 已加载|\[voice-ly\] 已加载|\[sing\]" | tail -6

echo ""
echo "=== 4. 全部插件加载异常检查 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "加载失败|Failed to load|Traceback" | tail -5 || echo "  无错误"
