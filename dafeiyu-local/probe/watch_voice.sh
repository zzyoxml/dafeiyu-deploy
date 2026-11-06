#!/bin/bash
set -u
echo "=== 等待 /流萤说（最多 4 分钟，含 RVC 变声）==="
for i in $(seq 1 48); do
  sleep 5
  if docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -qE "13:(3[5-9]|4[0-9]).*(流萤说|voice-ly.*已附|voice-ly.*发送)"; then
    echo "  ✅ 检测到（第 $i 轮）"
    break
  fi
done

echo ""
echo "=== 1. 命令事件 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "core.event_bus.*流萤说" | tail -3

echo ""
echo "=== 2. voice-ly 处理过程 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[voice-ly\]" | tail -10

echo ""
echo "=== 3. 发出的回复 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Prepare to send" | tail -4

echo ""
echo "=== 4. 音频文件 ==="
ls -lht /opt/dafeiyu/data/astrbot/audio/voice-cache/*.mp3 2>/dev/null | head -3 || echo "  无缓存文件"

echo ""
echo "=== 5. Record 组件是否出现 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Record|record" | tail -3
