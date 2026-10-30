#!/bin/bash
set -u
echo "=== 1. 有没有「曲库」输出（我的 /歌单 回复特征）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "曲库|Prepare to send.*歌单" | tail -8 || echo "  无 —— /歌单 从未回复过"

echo ""
echo "=== 2. 13:20:00 ~ 13:21:20 全量时间线（只看事件与发送）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | grep -E "^\[13:2(0|1)" \
  | grep -E "core.event_bus|Prepare to send|\[guard\]|cmd_songlist|dsh-sing" \
  | head -40

echo ""
echo "=== 3. 用户 <主人QQ> 在 13:19~13:22 发的所有消息 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | grep "<主人QQ>" | grep "core.event_bus" \
  | sed -n '/13:19/,/13:23/p' | tail -12

echo ""
echo "=== 4. dsh-reply-guard 有没有拦（陈旧判定日志）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "滞后|限流拦下" | tail -8 || echo "  从未触发拦截"
