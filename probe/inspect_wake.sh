#!/bin/bash
set -u
echo "=== 1. CommandFilter.filter 方法 ==="
docker exec astrbot sh -c "grep -n -A40 'def filter' /AstrBot/astrbot/core/star/filter/command.py | head -60"

echo ""
echo "=== 2. wake_prefix 相关 ==="
docker exec astrbot sh -c "grep -rn 'wake_prefix' /AstrBot/astrbot/core/ 2>/dev/null | head -10"

echo ""
echo "=== 3. 当前配置的 wake_prefix（AstrBot 里默认是 / 或空）==="
docker exec astrbot python3 -c "
import json
p='/AstrBot/data/cmd_config.json'
s=open(p,encoding='utf-8-sig').read()
d=json.loads(s)
print('  wake_prefix =', repr(d.get('platform_settings',{}).get('wake_prefix')))
for k in ('wake_prefix','platform'): 
    if k in d: print(f'  {k} =', repr(d[k]))
" 2>&1
