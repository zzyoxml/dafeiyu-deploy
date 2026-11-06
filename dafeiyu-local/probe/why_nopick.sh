#!/bin/bash
set -u
cat > /tmp/why_nopick.py <<'PYEOF'
import sys, inspect
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location("s", "/AstrBot/data/plugins/dsh-sing/main.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

print("  SingPlugin 的方法:")
for n in sorted(dir(m.SingPlugin)):
    if n.startswith("cmd_") or n.startswith("_"):
        continue
    fn = getattr(m.SingPlugin, n)
    has = "有装饰器" if hasattr(fn, "__wrapped__") or n.startswith("cmd_") else "?"
    print(f"    {n}: {has}")

print()
src = inspect.getsource(m.SingPlugin)
idx = src.find("def cmd_pick")
print("  cmd_pick 源码位置:", idx)
if idx > 0:
    print("  前面内容:")
    print("   ", src[max(0,idx-250):idx].replace("\n", "\n    "))
PYEOF
docker cp /tmp/why_nopick.py astrbot:/tmp/why_nopick.py
docker exec astrbot python3 /tmp/why_nopick.py 2>&1 | tail -25
