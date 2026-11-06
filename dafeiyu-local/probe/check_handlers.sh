#!/bin/bash
set -u
echo "=== 1. 热重载后插件日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "dsh-sing|Plugin dsh-sing" | tail -3

echo ""
echo "=== 2. 注册的处理器（regex 是否生效）==="
cat > /tmp/list_handlers.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

cls = mod.SingPlugin
for name in sorted(dir(cls)):
    if not name.startswith("cmd_"):
        continue
    fn = getattr(cls, name)
    doc = (fn.__doc__ or "").strip().splitlines()
    # 找挂在函数上的 filter 元数据
    filters = getattr(fn, "__filter_list__", None) or getattr(fn, "filter_list", None)
    print(f"  {name}:")
    print(f"    doc: {doc[0] if doc else '(无)'}")
    if filters:
        for f in filters:
            print(f"    filter: {type(f).__name__} {getattr(f,'regex_str','')}")
    else:
        # 从属性探测
        attrs = [a for a in dir(fn) if "filter" in a.lower() or "handler" in a.lower()]
        print(f"    attrs: {attrs}")
PYEOF
docker cp /tmp/list_handlers.py astrbot:/tmp/list_handlers.py
docker exec astrbot python3 /tmp/list_handlers.py 2>&1 | tail -30
