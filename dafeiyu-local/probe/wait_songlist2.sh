#!/bin/bash
set -u
echo "=== 1. 等待 /歌单 到达 ==="
for i in $(seq 1 24); do
  sleep 5
  if docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -q "13:2[0-9].*/歌单\|歌单.*Prepare"; then
    break
  fi
done

echo ""
echo "=== 2. 最近的歌单命令与回复 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "core.event_bus|Prepare to send" | tail -6

echo ""
echo "=== 3. 是否有异常（songlist 报错）==="
ERR=$(docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -c "cmd_songlist.*handle error" || true)
echo "  报错次数: $ERR"
if [ "$ERR" != "0" ]; then
  docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -A5 "cmd_songlist" | tail -10
fi
