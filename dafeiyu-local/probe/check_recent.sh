#!/bin/bash
set -u
echo "=== 13:43 之后的运行情况 ==="
echo ""
echo "【1. voice-ly 是否自动出过声（20% 概率钩子）】"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:4[3-9]|14:0[0-6]/' | grep -E "\[voice-ly\]" | tail -10 || echo "  无活动"

echo ""
echo "【2. reply-guard 是否拦过（限流/滞后）】"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:4[3-9]|14:0[0-6]/' | grep -E "\[guard\]" | grep -v "已加载" | tail -10 || echo "  无拦截记录"

echo ""
echo "【3. sing 是否有新任务】"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:4[3-9]|14:0[0-6]/' | grep -E "\[sing\]" | tail -8 || echo "  无"

echo ""
echo "【4. 最近消息与回复】"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:4[3-9]|14:0[0-6]/' | grep -E "core.event_bus|Prepare to send" | tail -12

echo ""
echo "【5. 异常】"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:4[3-9]|14:0[0-6]/' | grep -E "handle error|Traceback|合成失败" | tail -5 || echo "  无"
