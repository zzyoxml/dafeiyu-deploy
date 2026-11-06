#!/bin/bash
set -u
echo "等待 /歌单 消息到达..."
for i in $(seq 1 20); do
  sleep 5
  HOOK=$(docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "歌单|曲库" | tail -1)
  if [ -n "$HOOK" ]; then
    echo "  命中日志: $HOOK"
    break
  fi
done

echo ""
echo "=== 最近事件 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "core.event_bus" | tail -4

echo ""
echo "=== 最近回复 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Prepare to send" | tail -3
