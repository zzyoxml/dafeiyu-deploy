#!/bin/bash
set -u
START=$(date '+%H:%M:%S')
echo "=== 精确等待 /流萤说（从现在开始，最多 4 分钟）当前 $START ==="
FOUND=0
for i in $(seq 1 48); do
  sleep 5
  # 只匹配「流萤说」这个词的事件
  if docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -q "流萤说"; then
    echo "  ✅ 检测到「流萤说」关键词（第 $i 轮）"
    FOUND=1
    break
  fi
done

echo ""
echo "=== 1. 流萤说 事件 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -n "流萤说" | tail -5

echo ""
echo "=== 2. 13:35 之后的 voice-ly 日志（排除 403）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | awk '/13:3[5-9]|13:4[0-9]/' | grep -E "\[voice-ly\]" | grep -v "403" | tail -10

echo ""
echo "=== 3. 13:36 之后所有发送 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | awk '/^\[13:3[6-9]|^\[13:4/' | grep -E "Prepare to send|event_bus" | tail -8

echo ""
echo "=== 4. 音频产物 ==="
ls -lht /opt/dafeiyu/data/astrbot/audio/voice-cache/ 2>/dev/null | head -4
