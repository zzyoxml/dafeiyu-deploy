#!/bash
set -u
echo "=== 1. is_at_or_wake_command 与 message_str 的实现 ==="
docker exec astrbot sh -c "grep -n -B3 -A25 'def is_at_or_wake_command\|is_at_or_wake_command' /AstrBot/astrbot/core/platform/astr_message_event.py 2>/dev/null | head -50"

echo ""
echo "=== 2. aiocqhttp 平台怎么剥离 @ ==="
docker exec astrbot sh -c "grep -rn 'At\|at_' /AstrBot/astrbot/core/platform/sources/aiocqhttp/aiocqhttp_event.py 2>/dev/null | head -20"

echo ""
echo "=== 3. 实际收到的消息结构（从之前日志可见 @小鲸鱼）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "awareness.*message_str|awareness.*dump" | tail -2 | head -c 1200
