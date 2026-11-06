#!/bin/bash
set -u
echo "=== 1. 全量日志里搜 12:29 前后的唱歌请求 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -nE "12:29|12:30" | grep -iE "sing|唱歌|翻唱|原唱|正在处理|event_bus" | head -30

echo ""
echo "=== 2. grep 正在处理 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "正在处理" | tail -10

echo ""
echo "=== 3. grep 未就绪 / 需要主人 / 冷却 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "未就绪|需要主人权限|刚唱过|刚唱完|排队|唱歌失败|没发出去" | tail -10

echo ""
echo "=== 4. 找发送的文本（respond.stage）12:29 附近 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Prepare to send" | tail -15

echo ""
echo "=== 5. 容器当前时间 vs 日志时间 ==="
echo "  容器时间: $(docker exec astrbot date '+%H:%M:%S')"
echo "  宿主机时间: $(date '+%H:%M:%S')"
