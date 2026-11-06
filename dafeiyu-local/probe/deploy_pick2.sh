#!/bin/bash
set -u
echo "=== 1. 部署 ==="
cp /mnt/d/xml/dafeiyu/dafeiyu-local/probe/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
echo "  已复制"

echo ""
echo "=== 2. 语法 + 导入 + 正则测试 ==="
docker cp /mnt/d/xml/dafeiyu/dafeiyu-local/probe/check_pick.py astrbot:/tmp/check_pick.py
docker exec astrbot python3 /tmp/check_pick.py 2>&1 | tail -20

echo ""
echo "=== 3. 热重载 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
curl -s -m 30 -X POST "http://127.0.0.1:6185/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 150
echo ""
sleep 3

echo "=== 4. 加载确认 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Removed handler cmd_|Plugin dsh-sing" | tail -8
