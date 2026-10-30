#!/bin/bash
set -u
echo "=== 1. 命令是否注册（查 AstrBot 命令表）==="
cat > /tmp/list_cmds.py <<'PYEOF'
import sqlite3, json, os
# AstrBot 命令注册在内存里，这里换查插件对象
import importlib.util, sys
sys.path.insert(0, "/AstrBot")
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
cls = mod.SingPlugin
print("  插件类方法:")
for name in dir(cls):
    if name.startswith("cmd_"):
        fn = getattr(cls, name)
        doc = (fn.__doc__ or "").strip().splitlines()
        print(f"    {name}: {doc[0] if doc else '(无 doc)'}")
PYEOF
docker cp /tmp/list_cmds.py astrbot:/tmp/list_cmds.py
docker exec astrbot python3 /tmp/list_cmds.py 2>&1

echo ""
echo "=== 2. 直接测插件内部函数（不经过 QQ）==="
cat > /tmp/unit_test.py <<'PYEOF'
import asyncio, sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

async def main():
    print("--- readiness ---")
    checks = await mod._readiness()
    for k, v in checks.items():
        mark = "OK " if v["ok"] else "FAIL"
        print(f"  [{mark}] {k}: {v.get('detail') or v.get('path')}")
    print("\n--- missing_for_ai ---")
    print("  ", mod._missing_for_ai(checks) or "无缺失")

    print("\n--- search 夜曲 ---")
    try:
        rs = await mod._search_songs("夜曲", 3)
        for i, r in enumerate(rs, 1):
            print(f"  {i}. {r['title'][:40]} [{r['duration']}s]")
    except Exception as e:
        print("  搜索失败:", e)

asyncio.run(main())
PYEOF
docker cp /tmp/unit_test.py astrbot:/tmp/unit_test.py
docker exec astrbot python3 /tmp/unit_test.py 2>&1 | tail -30
