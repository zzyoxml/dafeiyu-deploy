#!/bin/bash
set -u
echo "=== 1. 选歌时 Record 是否真发出（13:27:55~13:28:05）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | awk '/13:27:5[5-9]/,/13:28:1/' \
  | grep -vE "awareness|dsh-proactive|dsh-decide|dsh-persona" | head -20

echo ""
echo "=== 2. voice-ly 是否有活动（20% 概率触发过吗）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[voice-ly\]" | tail -12 || echo "  从未触发"

echo ""
echo "=== 3. 「你会发语音吗」这条的处理（13:31:00）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:31:0/,0' | head -20

echo ""
echo "=== 4. 语音缓存数量 ==="
ls /opt/dafeiyu/data/astrbot/audio/voice-cache/*.mp3 2>/dev/null | wc -l

echo ""
echo "=== 5. dsh-voice（老的 Fish/Edge 插件）最近日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[voice\]" | tail -6
