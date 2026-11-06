#!/bin/bash
set -u
echo "=== 1. regex filter 是否也要求 wake prefix ==="
docker exec astrbot sh -c "cat /AstrBot/astrbot/core/star/filter/regex.py 2>/dev/null | head -40"

echo ""
echo "=== 2. 其他 dsh 插件怎么处理 @ 前缀的（找现成范例）==="
for f in dsh-imagegen dsh-sticker dsh-voice dsh-fwd; do
  r=$(docker exec astrbot sh -c "grep -n 'At\|@\|mention\|nickname' /AstrBot/data/plugins/$f/main.py 2>/dev/null | grep -iE 'strip|remove|re.sub|lstrip|startswith' | head -3")
  if [ -n "$r" ]; then
    echo "  [$f]"
    echo "$r" | sed 's/^/    /'
  fi
done

echo ""
echo "=== 3. 现有插件用的 filter 类型分布 ==="
docker exec astrbot sh -c "grep -rh 'filter\.\(command\|regex\|event_message_type\)' /AstrBot/data/plugins/dsh-imagegen/main.py 2>/dev/null | sed 's/^ *//' | sort | uniq -c | head -10"
