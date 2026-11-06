#!/bin/bash
set -u
echo "=== 1. 13:14:59 前后的完整插件日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:14:5[6-9]/,/13:15:1/' | grep -vE "awareness|core.event_bus" | head -30

echo ""
echo "=== 2. 谁发的 :( ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -B8 "Prepare to send.*:(" | tail -15

echo ""
echo "=== 3. dsh-acl 是否拦截命令 ==="
docker exec astrbot sh -c "grep -n '歌单\|白名单\|unknown\|未登记\|拦截' /AstrBot/data/plugins/dsh-acl/main.py | head -12"
