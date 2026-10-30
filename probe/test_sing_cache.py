"""端到端验证唱歌缓存：模拟两次相同的点歌，第二次必须走缓存。"""
import sys
import time

sys.path.insert(0, "/AstrBot")
import importlib.util

s = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)

print("=" * 60)
st = m._cache_stats()
print(f"① 当前曲库 {st['count']}/{st['max']} 首，{st['bytes']//1048576}MB")
for k, v in m._cache_load()["entries"].items():
    print(f"   [{k}] {v['song']} {v['seconds']}s mode={v['mode']} "
          f"hits={v.get('hits',0)} {v['bytes']//1024}KB")
print()

print("② 缓存命中语义测试")
cases = [
    ("全球变冷 60s AI        ", ("全球变冷", "ai", 60, 0, 0, ""), True),
    ("全球变冷 30s AI        ", ("全球变冷", "ai", 30, 0, 0, ""), False),
    ("全球变冷 60s 原唱      ", ("全球变冷", "original", 60, 0, 0, ""), False),
    ("八千里路 60s AI        ", ("唱八千里路明月照完整版", "ai", 60, 0, 0, ""), True),
    ("不存在的歌             ", ("随便什么", "ai", 60, 0, 0, ""), False),
]
for label, args, want in cases:
    k = m._cache_key(*args)
    t0 = time.time()
    p = m._cache_get(k)
    dt = (time.time() - t0) * 1000
    got = p is not None
    print(f"   {'✅' if got == want else '❌'} {label} → {'命中' if got else '未命中'} ({dt:.1f}ms)")
print()

print("③ LRU 淘汰模拟（上限 3，验证淘汰最久未用）")
import shutil
from pathlib import Path

tmp = Path("/tmp/lru-test")
shutil.rmtree(tmp, ignore_errors=True)
tmp.mkdir(parents=True)
m.CACHE_DIR = tmp
m.CACHE_INDEX = tmp / "index.json"
m.CACHE_MAX = 3

fake = Path("/tmp/lru-fake.mp3")
fake.write_bytes(b"X" * 2048)

# 写入 A、B、C
for name in ["歌A", "歌B", "歌C"]:
    k = m._cache_key(name, "ai", 30, 0, 0, name)
    m._cache_put(k, fake, name, "ai", 30, 0, 0, name, "bili")
    time.sleep(0.08)

d = m._cache_load()["entries"]
print(f"   写入 3 首: {sorted(v['song'] for v in d.values())}")

# 使用 A（刷新其 last_used）
kA = m._cache_key("歌A", "ai", 30, 0, 0, "歌A")
m._cache_get(kA)
time.sleep(0.08)

# 写入 D → 应淘汰 B（最久未用，而非 A）
kD = m._cache_key("歌D", "ai", 30, 0, 0, "歌D")
m._cache_put(kD, fake, "歌D", "ai", 30, 0, 0, "歌D", "bili")

d = m._cache_load()["entries"]
remain = sorted(v["song"] for v in d.values())
print(f"   写入第4首后: {remain}")
print(f"   {'✅' if '歌A' in remain and '歌B' not in remain else '❌'} A 保留、B 被淘汰")
print(f"   文件数: {len(list(tmp.glob('*.mp3')))}（应 3）")

shutil.rmtree(tmp, ignore_errors=True)
fake.unlink(missing_ok=True)
print()
print("④ 真实曲库未受影响:", m._cache_stats() if m.CACHE_INDEX.name == "index.json" else "（已切临时目录）")
