#!/bin/bash
set -u
echo "=== 等待 /歌单 与 数字 1（最多 3 分钟）==="
for i in $(seq 1 36); do
  sleep 5
  HIT=$(docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -cE "曲库|选 ..发送缓存|Record" || true)
  CUR=$(tail -1 /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null | head -c 80)
  if docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -q "Prepare to send.*曲库"; then
    echo "  ✅ 曲库已发出（第 $i 轮）"
    break
  fi
done

echo ""
echo "=== 1. 曲库输出 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -A4 "Prepare to send.*曲库" | tail -8

echo ""
echo "=== 2. 数字 1 的处理 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "<主人QQ>: 1$|选 ..发送缓存|Prepare to send.*🎶" | tail -6

echo ""
echo "=== 3. cmd_pick 是否被调用 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[sing\] 选|cmd_pick" | tail -5 || echo "  未见 cmd_pick 日志"

echo ""
echo "=== 4. 最近事件时间线 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | grep -E "core.event_bus|Prepare to send" | tail -10
