#!/bin/bash
set -u
echo "=== 1. 按语义去重（歌名+模式+时长+起+变调），不按文件名 ==="
cat > /tmp/dedup2.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

data = mod._cache_load()
entries = data.get("entries") or {}
print(f"  去重前 {len(entries)} 条")

# 语义键 = (song, mode, seconds, start, pitch)
groups = {}
for k, v in entries.items():
    sem = (v.get("song"), v.get("mode"), v.get("seconds"),
           v.get("start"), v.get("pitch"))
    # 保留 last_used 最新、hits 最多的那条
    if sem not in groups:
        groups[sem] = (k, v)
    else:
        old = groups[sem][1]
        if (v.get("last_used", 0) > old.get("last_used", 0)):
            # 删掉旧的物理文件
            try:
                (mod.CACHE_DIR / old.get("file","")).unlink(missing_ok=True)
            except Exception:
                pass
            groups[sem] = (k, v)
        else:
            try:
                (mod.CACHE_DIR / v.get("file","")).unlink(missing_ok=True)
            except Exception:
                pass

new = {k: v for k, v in groups.values()}
data["entries"] = new
mod._cache_save(data)
print(f"  去重后 {len(new)} 条:")
for k, v in new.items():
    print(f"    {k} → {v['song']} {v['seconds']}s mode={v['mode']} hits={v.get('hits',0)}")
print()
st = mod._cache_stats()
print(f"  stats: {st['count']}/{st['max']} 首 {st['bytes']//1048576}MB")
PYEOF
docker cp /tmp/dedup2.py astrbot:/tmp/dedup2.py
docker exec astrbot python3 /tmp/dedup2.py 2>&1 | tail -12

echo ""
echo "=== 2. 验证 _cache_put 现在的去重逻辑（模拟同语义两次写入）==="
cat > /tmp/test_dedup.py <<'PYEOF'
import sys, time
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

from pathlib import Path
mod.CACHE_INDEX.unlink(missing_ok=True)
import shutil
shutil.rmtree(mod.CACHE_DIR, ignore_errors=True)

fake = Path("/tmp/f.mp3"); fake.write_bytes(b"X"*2048)
# 同一首歌，两把不同的键（quick 与 exact）
k1 = mod._cache_key("测试歌","ai",30,0,0,"")
k2 = mod._cache_key("测试歌","ai",30,0,0,"某音源标题")
print(f"  quick={k1}")
print(f"  exact={k2}")
mod._cache_put(k1, fake, "测试歌","ai",30,0,0,"某音源标题","bilibili")
time.sleep(0.05)
mod._cache_put(k2, fake, "测试歌","ai",30,0,0,"某音源标题","bilibili")

st = mod._cache_stats()
print(f"  两次写入后条数: {st['count']} (应 1，因语义相同)")
d = mod._cache_load()["entries"]
for k,v in d.items():
    print(f"    {k} → {v['song']}")

mod.CACHE_INDEX.unlink(missing_ok=True)
shutil.rmtree(mod.CACHE_DIR, ignore_errors=True)
fake.unlink(missing_ok=True)
PYEOF
docker cp /tmp/test_dedup.py astrbot:/tmp/test_dedup.py
docker exec astrbot python3 /tmp/test_dedup.py 2>&1 | tail -10
