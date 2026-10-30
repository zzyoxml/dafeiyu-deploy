#!/bin/bash
set -u
echo "=== 1. NapCat 侧是否收到发送请求（13:37:30~13:37:35）==="
docker logs napcat 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:37:2[5-9]|13:37:3[0-9]/' | tail -20

echo ""
echo "=== 2. AstrBot 侧 13:37:28~13:37:40 全部日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | awk '/13:37:2[89]/,/13:37:4/' | head -25

echo ""
echo "=== 3. tts 文件是否还在（发出后通常清理）==="
docker exec astrbot sh -c "ls -lht /AstrBot/data/voice/ 2>/dev/null | head -5"

echo ""
echo "=== 4. 该消息的最终发送内容 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "respond.stage.*1793338651|Prepare to send.*会啊" | tail -3
