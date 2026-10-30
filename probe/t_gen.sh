#!/usr/bin/env bash
# 在容器内直接调 dsh-imagegen 的 _generate()，验证补丁真的能用
set -u
cat > /tmp/t_gen.py <<'PYEOF'
import asyncio, os, sys, importlib.util

P = "/AstrBot/data/plugins/dsh-imagegen/main.py"
spec = importlib.util.spec_from_file_location("imggen", P)
m = importlib.util.module_from_spec(spec)
sys.modules["imggen"] = m
try:
    spec.loader.exec_module(m)
except SystemExit:
    pass

print("  BACKEND =", getattr(m, "BACKEND", "?"))
print("  POLL_MODEL =", getattr(m, "POLL_MODEL", "?"))
print("  SIZE =", m.SIZE)
print()

async def go():
    path, err = await m._generate("一只圆滚滚的蓝白胖鲸鱼，Q版可爱")
    print("  path =", path)
    print("  err  =", err)
    if path and os.path.isfile(path):
        sz = os.path.getsize(path)
        print("  ✓ 成功，%d 字节" % sz)
        print("  FILE:", path)
    else:
        print("  ✗ 失败")

asyncio.run(go())
PYEOF
docker cp /tmp/t_gen.py astrbot:/tmp/t_gen.py
docker exec astrbot python3 /tmp/t_gen.py 2>&1
