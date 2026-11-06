#!/bin/bash
set -u
echo "=== 等待数字 1（新消息，13:28 之后）最多 3 分钟 ==="
for i in $(seq 1 36); do
  sleep 5
  if docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -qE "13:(2[89]|3[0-9]).*: 1$"; then
    echo "  ✅ 检测到数字 1（第 $i 轮）"
    break
  fi
done

echo ""
echo "=== 1. 数字 1 事件 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "core.event_bus.*: 1$" | tail -3

echo ""
echo "=== 2. cmd_pick 触发日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[sing\] 选|\[sing\] 步骤：send" | tail -5 || echo "  未触发"

echo ""
echo "=== 3. 发出的内容 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Prepare to send.*🎶|Record" | tail -5

echo ""
echo "=== 4. 完整时间线（最后 8 条）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | grep -E "core.event_bus|Prepare to send|\[sing\]" | tail -8
