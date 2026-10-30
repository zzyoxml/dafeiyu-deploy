#!/bin/bash
set -u
echo "=== 1. 部署 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
echo "  已复制"

echo ""
echo "=== 2. 语法 + 导入 ==="
docker exec astrbot python3 /tmp/check_sing.py 2>&1 | grep -E "语法|导入|插件类|STATUS"

echo ""
echo "=== 3. 缓存逻辑单元测试 ==="
cat > /tmp/test_cache.py <<'PYEOF'
import sys, time, shutil
from pathlib import Path
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

print("  CACHE_DIR =", mod.CACHE_DIR)
print("  CACHE_MAX =", mod.CACHE_MAX)
print()

# 1. 键稳定性
k1 = mod._cache_key("全球变冷", "ai", 60, 0, 0, "【4K Hi-Res】全球变冷-许嵩")
k2 = mod._cache_key("全球变冷", "ai", 60, 0, 0, "【4K Hi-Res】全球变冷-许嵩")
k3 = mod._cache_key("全球变冷", "ai", 30, 0, 0, "【4K Hi-Res】全球变冷-许嵩")
k4 = mod._cache_key("全球变冷", "original", 60, 0, 0, "【4K Hi-Res】全球变冷-许嵩")
print("  键稳定性:")
print(f"    相同参数两次 = {k1 == k2} (应 True)")
print(f"    不同时长     = {k1 != k3} (应 True)")
print(f"    不同模式     = {k1 != k4} (应 True)")
print()

# 2. 写入/命中/淘汰（用假数据）
print("  缓存写入与淘汰测试（上限临时设为 3）:")
mod.CACHE_MAX = 3
mod.CACHE_DIR.mkdir(parents=True, exist_ok=True)
# 清空索引
mod.CACHE_INDEX.unlink(missing_ok=True)

fake = Path("/tmp/fake-song.mp3")
fake.write_bytes(b"X" * 2048)
for i, name in enumerate(["歌A", "歌B", "歌C"]):
    key = mod._cache_key(name, "ai", 30, 0, 0, f"title-{name}")
    mod._cache_put(key, fake, name, "ai", 30, 0, 0, f"title-{name}", "bilibili")
    time.sleep(0.05)
print("    写入3首后: count =", mod._cache_stats()["count"])

# 加第4首，触发淘汰
key4 = mod._cache_key("歌D", "ai", 30, 0, 0, "title-歌D")
mod._cache_put(key4, fake, "歌D", "ai", 30, 0, 0, "title-歌D", "bilibili")
st = mod._cache_stats()
print("    写入第4首后: count =", st["count"], "(应 3)")
print(f"    被淘汰的是: {st['oldest_song']} (应 歌A，最久未用)")
print()

# 3. 命中测试
print("  命中测试:")
keyA = mod._cache_key("歌A", "ai", 30, 0, 0, "title-歌A")
print(f"    查已淘汰的歌A = {mod._cache_get(keyA)} (应 None)")
keyB = mod._cache_key("歌B", "ai", 30, 0, 0, "title-歌B")
h = mod._cache_get(keyB)
print(f"    查存在的歌B   = {h.name if h else None}")
if h:
    data = mod._cache_load()
    print(f"    hits 计数     = {data['entries'][keyB]['hits']} (应 1)")

# 清理
mod.CACHE_INDEX.unlink(missing_ok=True)
shutil.rmtree(mod.CACHE_DIR, ignore_errors=True)
fake.unlink(missing_ok=True)
print()
print("  ✅ 缓存逻辑测试完成（已清理测试数据）")
PYEOF
docker cp /tmp/test_cache.py astrbot:/tmp/test_cache.py
docker exec astrbot python3 /tmp/test_cache.py 2>&1 | tail -30
