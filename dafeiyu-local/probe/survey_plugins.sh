#!/bin/bash
set -u
echo "=== 1. dsh-guard 是什么 ==="
docker exec astrbot sh -c "cat /AstrBot/data/plugins/dsh-guard/metadata.yaml"
echo ""
docker exec astrbot sh -c "grep -n '每分钟\|rate\|limit\|频率\|条数\|刷屏' /AstrBot/data/plugins/dsh-guard/main.py | head -10"

echo ""
echo "=== 2. dsh-ctxclean 是什么 ==="
docker exec astrbot sh -c "cat /AstrBot/data/plugins/dsh-ctxclean/metadata.yaml"
echo ""
docker exec astrbot sh -c "grep -n 'ctx\|上下文\|窗口\|limit' /AstrBot/data/plugins/dsh-ctxclean/main.py | head -10"

echo ""
echo "=== 3. dsh-voice 的音色/概率配置项 ==="
docker exec astrbot sh -c "grep -n 'VOICE_EDGE_VOICE\|PROB\|概率\|ref\|音色' /AstrBot/data/plugins/dsh-voice/main.py | head -20"
