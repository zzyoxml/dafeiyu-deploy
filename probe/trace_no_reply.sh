#!/bin/bash
set -u
echo "=== 1. 找 /歌单 事件 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -n "歌单" | tail -6

echo ""
echo "=== 2. 找用户发「1」的事件 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -nE "<主人QQ>: .*[^0-9]1$|: 1$|raw_message': '1'" | tail -6

echo ""
echo "=== 3. dsh-reply-guard 是否拦了消息（重点怀疑）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[guard\]" | tail -12

echo ""
echo "=== 4. dsh-sing 最近日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[sing\]" | tail -10

echo ""
echo "=== 5. 最近 10 条事件与回复（按时间）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | grep -E "core.event_bus|[[:space:]]Prepare to send" | tail -16
