#!/bin/bash
set -u
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
echo "=== 1. 通过 WebUI API 查插件命令列表 ==="
for ep in "plugin/list" "plugin/commands" "plugin/all" "plugins"; do
  r=$(curl -s -m 15 "http://127.0.0.1:6185/api/$ep" -H "Authorization: Bearer $JWT" 2>/dev/null)
  code=$(echo "$r" | head -c 60)
  echo "  /api/$ep -> ${code:0:60}"
done

echo ""
echo "=== 2. 直接查 star_map 里的 regex handler（容器内进程外无法访问，改用导入分析）==="
cat > /tmp/probe_filters.py <<'PYEOF'
import sys, inspect
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# @filter.regex 装饰器返回的是原函数，但会往函数的 __dict__ 或全局注册表写
import astrbot.api.event.filter as F
print("  filter 模块成员:", [n for n in dir(F) if not n.startswith("_")][:15])
print()

# 装饰器源码
src = inspect.getsource(F.regex) if hasattr(F, "regex") else ""
print("  @filter.regex 源码:")
for line in src.splitlines()[:20]:
    print("   ", line)
PYEOF
docker cp /tmp/probe_filters.py astrbot:/tmp/probe_filters.py
docker exec astrbot python3 /tmp/probe_filters.py 2>&1 | tail -25
