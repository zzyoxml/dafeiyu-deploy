#!/bin/bash
set -u
echo "=== 1. filter.command 的匹配实现 ==="
docker exec astrbot sh -c "cat /AstrBot/astrbot/core/star/filter/command.py 2>/dev/null | head -80"

echo ""
echo "=== 2. 是否有剥离 @ 的逻辑 ==="
docker exec astrbot sh -c "grep -rn 'At(\|ComponentType.At\|remove_at\|strip_at' /AstrBot/astrbot/core/star/filter/ 2>/dev/null | head -10"

echo ""
echo "=== 3. message_str 怎么算出来的 ==="
docker exec astrbot sh -c "grep -rn 'message_str' /AstrBot/astrbot/core/platform/astrbot_message.py 2>/dev/null | head -10"
