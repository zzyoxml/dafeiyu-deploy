#!/bin/bash
set -u
echo "=== 1. 检查所有 .values() / .items() 调用上下文 ==="
docker exec astrbot sh -c "grep -n '\.values()\|\.items()\|\.keys()' /AstrBot/data/plugins/dsh-sing/main.py" | sed 's/^/  /'

echo ""
echo "=== 2. 检查 _cache_stats 和 cmd_status 里缓存相关代码 ==="
sed -n '770,800p' /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py | grep -n "cache\|values\|ordered" | sed 's/^/  /'
