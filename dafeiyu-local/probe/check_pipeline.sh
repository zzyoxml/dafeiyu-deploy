#!/bin/bash
set -u
echo "=== 1. 热重载后的完整日志（找 regex handler 注册痕迹）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | tail -60 | grep -iE "dsh-sing|handler|register|regex|命令|指令" | tail -20

echo ""
echo "=== 2. 检查 star_manager 如何处理 regex 装饰器 ==="
docker exec astrbot sh -c "grep -n -A8 'EventType.AdapterMessageEvent' /AstrBot/astrbot/core/star/register/star_handler.py | head -30"

echo ""
echo "=== 3. 关键：regex handler 会不会被 command 处理流程跳过 ==="
docker exec astrbot sh -c "grep -n -B5 -A20 'is_at_or_wake_command' /AstrBot/astrbot/core/pipeline/*.py 2>/dev/null | head -40"
