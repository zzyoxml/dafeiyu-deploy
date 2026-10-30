#!/bin/bash
set -u
echo "=== filter 模块里所有可用的装饰器 ==="
cat > /tmp/list_filters.py <<'PYEOF'
import astrbot.api.event.filter as F
print("  公开成员:")
for n in dir(F):
    if n.startswith("_"):
        continue
    o = getattr(F, n)
    kind = "函数" if callable(o) else type(o).__name__
    print(f"    {n}  ({kind})")
PYEOF
docker cp /tmp/list_filters.py astrbot:/tmp/list_filters.py
docker exec astrbot python3 /tmp/list_filters.py 2>&1

echo ""
echo "=== 现有插件是怎么写 regex 过滤的（找真实用法）==="
docker exec astrbot sh -c "grep -rn 'register_regex\|filter.regex\|RegexFilter' /AstrBot/data/plugins/*/main.py 2>/dev/null | head -10"
echo ""
echo "  框架自带插件里的用法:"
docker exec astrbot sh -c "grep -rn 'register_regex' /AstrBot/astrbot/ 2>/dev/null | head -5"
