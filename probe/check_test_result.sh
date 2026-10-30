#!/bin/bash
set -u
echo "=== 1. [sing] 日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "\[sing\]" | tail -20

echo ""
echo "=== 2. 状态文件 ==="
cat /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null | tail -5 || echo "  尚无"

echo ""
echo "=== 3. 12:45 之后用户消息 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "core.event_bus" | tail -8

echo ""
echo "=== 4. 12:45 之后发出的回复 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Prepare to send" | tail -8

echo ""
echo "=== 5. 产物 ==="
ls -lht /opt/dafeiyu/data/astrbot/audio/*.mp3 2>/dev/null | head -3 || echo "  无"
