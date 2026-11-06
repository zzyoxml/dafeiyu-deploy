#!/bin/bash
set -u
echo "=== 1. 那个工作目录里有什么 ==="
find /opt/dafeiyu/data/astrbot/sing/work/ai-20261030122912 -type f -o -type d 2>/dev/null | head -20
echo "  内容大小:"
du -sh /opt/dafeiyu/data/astrbot/sing/work/ai-20261030122912 2>/dev/null

echo ""
echo "=== 2. 12:28-12:32 时间段的完整日志（不带过滤）==="
docker logs astrbot --since 12:28:00 --until 12:32:00 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -vE "^$" | tail -60

echo ""
echo "=== 3. 用户发的原始消息（找 12:29 附近）==="
docker logs astrbot --since 12:28:00 --until 12:31:00 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "event_bus|message_str|收到了|raw_message" | tail -20
