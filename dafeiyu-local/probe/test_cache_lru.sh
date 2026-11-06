#!/bin/bash
set -u
cat > /tmp/test_cache2.py <<'PYEOF'
import sys, time, shutil
from pathlib import Path
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

mod.CACHE_MAX = 3
mod.CACHE_DIR.mkdir(parents=True, exist_ok=True)
mod.CACHE_INDEX.unlink(missing_ok=True)
fake = Path("/tmp/fake.mp3"); fake.write_bytes(b"X"*2048)

print("按顺序写入 A B C，间隔递增，预测淘汰 A:")
for name in ["歌A","歌B","歌C"]:
    k = mod._cache_key(name,"ai",30,0,0,name)
    mod._cache_put(k, fake, name, "ai", 30,0,0,name, "bilibili")
    time.sleep(0.1)

d = mod._cache_load()["entries"]
print("  last_used 排序:")
for k,v in sorted(d.items(), key=lambda kv: kv[1]["last_used"]):
    print(f"    {v['song']}: {v['last_used']:.3f}")

print()
print("现在「使用」歌A（刷新它的 last_used），再写入D，验证淘汰 B 而非 A:")
kA = mod._cache_key("歌A","ai",30,0,0,"歌A")
mod._cache_get(kA)
time.sleep(0.1)
kD = mod._cache_key("歌D","ai",30,0,0,"歌D")
mod._cache_put(kD, fake, "歌D","ai",30,0,0,"歌D","bilibili")

d = mod._cache_load()["entries"]
remain = sorted(v["song"] for v in d.values())
print(f"  剩余: {remain}")
print(f"  → 歌A 应保留（刚用过），歌B 应被淘汰: {'歌A' in remain and '歌B' not in remain}")

mod.CACHE_INDEX.unlink(missing_ok=True)
shutil.rmtree(mod.CACHE_DIR, ignore_errors=True)
fake.unlink(missing_ok=True)
PYEOF
docker cp /tmp/test_cache2.py astrbot:/tmp/test_cache2.py
docker exec astrbot python3 /tmp/test_cache2.py 2>&1 | grep -v "缓存命中\|超上限" | tail -18
