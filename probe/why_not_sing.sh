#!/bin/bash
set -u
echo "=== 1. 状态文件（插件自己的记录）==="
cat /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null | tail -10 || echo "  ❌ 状态文件不存在 → 插件从未处理过点歌"

echo ""
echo "=== 2. 工作目录 ==="
ls -lht /opt/dafeiyu/data/astrbot/sing/work/ 2>/dev/null | head -5 || echo "  无"

echo ""
echo "=== 3. 已产出语音 ==="
ls -lht /opt/dafeiyu/data/astrbot/audio/*.mp3 2>/dev/null | head -5 || echo "  无"

echo ""
echo "=== 4. dsh-sing 全部日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "\[sing\]" | tail -20

echo ""
echo "=== 5. 用户最近发的消息（原始接收）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "core.event_bus" | tail -15

echo ""
echo "=== 6. 最近 5 分钟所有发送回复 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Prepare to send" | tail -10
