#!/bin/bash
set -u
echo "=== 1. 源码里 cmd_pick 是否存在 ==="
docker exec astrbot sh -c "grep -n 'cmd_pick' /AstrBot/data/plugins/dsh-sing/main.py" | sed 's/^/  /'

echo ""
echo "=== 2. cmd_pick 上方 12 行（看装饰器有没有挂上）==="
docker exec astrbot sh -c "grep -n -B12 'async def cmd_pick' /AstrBot/data/plugins/dsh-sing/main.py" | sed 's/^/  /'

echo ""
echo "=== 3. 已注册的全部 handler（热重载日志）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | grep -A13 "Loading plugin dsh-sing" | tail -16
