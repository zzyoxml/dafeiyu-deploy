import sys
sys.path.insert(0, "/AstrBot")
import importlib.util

s = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)

print("=" * 60)
print("真实曲库里每条记录的完整参数：")
for k, v in m._cache_load()["entries"].items():
    print(f"  key={k}")
    for f in ("song", "mode", "seconds", "start", "pitch", "title"):
        print(f"    {f:8} = {v.get(f)!r}")
    # 用记录自身的参数重算 key，看能否对上
    recomputed = m._cache_key(
        v["song"], v["mode"], v["seconds"], v["start"], v["pitch"], v.get("title", ""))
    recomputed_quick = m._cache_key(
        v["song"], v["mode"], v["seconds"], v["start"], v["pitch"], "")
    print(f"    重算(带标题) = {recomputed} {'✅ 一致' if recomputed == k else '❌ 不一致'}")
    print(f"    重算(无标题) = {recomputed_quick}")
    print()

print("查询侧用的参数（start=0, pitch=0）：")
for song, mode, sec in [("全球变冷", "ai", 60), ("唱八千里路明月照完整版", "ai", 60)]:
    k = m._cache_key(song, mode, sec, 0, 0, "")
    hit = m._cache_get(k)
    print(f"  {song} {sec}s {mode} → key={k} → {'命中' if hit else '未命中'}")
