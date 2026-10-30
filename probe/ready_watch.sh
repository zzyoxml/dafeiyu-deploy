#!/bin/bash
set -u
echo "=== 当前监听预备状态 ==="
echo "  容器时间: $(docker exec astrbot date '+%H:%M:%S')"
echo "  插件版本: $(docker exec astrbot sh -c "stat -c '%y' /AstrBot/data/plugins/dsh-sing/main.py")"
echo ""
echo "  已注册的命令（从热重载日志）:"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Removed handler cmd_" | tail -5
echo ""
echo "  状态文件（点歌后会有记录）:"
ls -la /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null || echo "    尚无 → 还没处理过命令"
echo ""
echo "  === 以下是我会盯的日志位置 ==="
echo "    1. [sing] 步骤：xxx     ← 插件内部进度"
echo "    2. Prepare to send      ← 实际回复"
echo "    3. status.jsonl         ← 持久化记录"
