import importlib.util
import ast
import sys
import shutil
from pathlib import Path

P = "/AstrBot/data/plugins/dsh-sing/main.py"

# 语法
ast.parse(open(P, encoding="utf-8").read())
print("  语法 OK")

sys.path.insert(0, "/AstrBot")
s = importlib.util.spec_from_file_location("sing", P)
m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)
print("  ✅ 导入成功")

print()
print("① 迁移已有缓存条目到新语义键")
data = m._cache_load()
entries = data.get("entries") or {}
old_n = len(entries)
new_entries = {}
moved = 0
for k, v in entries.items():
    newk = m._cache_key(v["song"], v["mode"], v["seconds"],
                        v.get("start", 0), v.get("pitch", 0))
    if newk != k:
        moved += 1
        # 文件改名成新键，避免残留
        oldf = m.CACHE_DIR / v.get("file", "")
        newf = m.CACHE_DIR / f"{newk}.mp3"
        if oldf.exists() and not newf.exists():
            oldf.rename(newf)
        v["file"] = newf.name
    new_entries[newk] = v
data["entries"] = new_entries
m._cache_save(data)
print(f"   {old_n} 条 → {len(new_entries)} 条，改键 {moved} 条")
for k, v in new_entries.items():
    print(f"   {k} ← {v['song']} {v['seconds']}s {v['mode']}")

print()
print("② 按真实点歌参数查缓存（应全部命中）")
for song, mode, sec in [("全球变冷", "ai", 60),
                        ("唱八千里路明月照完整版", "ai", 60)]:
    k = m._cache_key(song, mode, sec, 0, 0)
    hit = m._cache_get(k)
    print(f"   {song} {sec}s {mode} → {'✅ 命中 ' + hit.name if hit else '❌ 未命中'}")

print()
print("③ 参数不同不应命中")
for song, mode, sec, start in [("全球变冷", "ai", 30, 0),
                               ("全球变冷", "original", 60, 0),
                               ("全球变冷", "ai", 60, 20)]:
    k = m._cache_key(song, mode, sec, start, 0)
    hit = m._cache_get(k)
    print(f"   {song} {sec}s {mode} start={start} → {'⚠ 意外命中' if hit else '✅ 未命中（正确）'}")
