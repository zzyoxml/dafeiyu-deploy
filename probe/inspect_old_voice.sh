#!/bin/bash
set -u
echo "=== 1. 查看 dsh-voice 的 edge 合成实现 ==="
docker exec astrbot sh -c "sed -n '1000,1030p' /AstrBot/data/plugins/dsh-voice/main.py"

echo ""
echo "=== 2. 是否有独立函数可改 ==="
docker exec astrbot sh -c "grep -n 'edge_tts\|Edge 合成\|_synthesize\|Communicate' /AstrBot/data/plugins/dsh-voice/main.py | head -12"
