#!/bin/bash
set -u
echo "=== 1. 播种缓存：把之前生成的《全球变冷》收进缓存 ==="
cat > /tmp/seed_cache.py <<'PYEOF'
import sys, time
from pathlib import Path
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# 用之前成功生成的成品做种子
src = Path("/AstrBot/data/audio/sing-4K-Hi-Res-全球变冷-许嵩-看得透-放得下-拈花一朵-ai-20261030125319.mp3")
print(f"  源文件存在: {src.exists()}, {src.stat().st_size//1024}KB" if src.exists() else "  ❌ 源不存在")

title = "【4K Hi-Res】全球变冷-许嵩  看得透 放得下 拈花一朵"
# quick 键（无标题）—— 这是命中率最高的那条
k_quick = mod._cache_key("全球变冷", "ai", 60, 0, 0, "")
# 精确键（带标题）
k_exact = mod._cache_key("全球变冷", "ai", 60, 0, 0, title)
print(f"  quick 键: {k_quick}")
print(f"  exact 键: {k_exact}")

mod._cache_put(k_quick, src, "全球变冷", "ai", 60, 0, 0, title, "bilibili")
mod._cache_put(k_exact, src, "全球变冷", "ai", 60, 0, 0, title, "bilibili")

st = mod._cache_stats()
print(f"  缓存: {st['count']}/{st['max']} 首，{st['bytes']//1048576}MB")
PYEOF
docker cp /tmp/seed_cache.py astrbot:/tmp/seed_cache.py
docker exec astrbot python3 /tmp/seed_cache.py 2>&1 | tail -8

echo ""
echo "=== 2. 验证缓存命中（关键：应 <50ms 返回路径）==="
cat > /tmp/test_hit.py <<'PYEOF'
import sys, time
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

for label, args in [
    ("quick 键（无标题）", ("全球变冷","ai",60,0,0,"")),
    ("exact 键（带标题）", ("全球变冷","ai",60,0,0,"【4K Hi-Res】全球变冷-许嵩  看得透 放得下 拈花一朵")),
    ("错误：30秒",        ("全球变冷","ai",30,0,0,"")),
    ("错误：原唱模式",     ("全球变冷","original",60,0,0,"")),
    ("错误：别的歌",       ("十年","ai",60,0,0,"")),
]:
    k = mod._cache_key(*args)
    t0 = time.time()
    p = mod._cache_get(k)
    dt = (time.time()-t0)*1000
    print(f"  {label:22} → {'命中 ' + p.name if p else '未命中'} ({dt:.0f}ms)")
PYEOF
docker cp /tmp/test_hit.py astrbot:/tmp/test_hit.py
docker exec astrbot python3 /tmp/test_hit.py 2>&1 | tail -10
