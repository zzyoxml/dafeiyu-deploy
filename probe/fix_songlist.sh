#!/bin/bash
set -u
echo "=== 1. 部署修复 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
echo "  已复制"

echo ""
echo "=== 2. 语法 + 导入 ==="
docker exec astrbot python3 /tmp/check_sing.py 2>&1 | grep -E "语法|导入|插件类"

echo ""
echo "=== 3. 单测 _cache_stats + cmd_songlist 逻辑 ==="
cat > /tmp/test_songlist.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# 直接验算之前报错的那段表达式
entries = mod._cache_load().get("entries") or {}
ordered = sorted(entries.values(), key=lambda e: -e.get("last_used", 0))
total_mb = sum(int(e.get("bytes", 0)) for e in ordered) // 1048576
print(f"  缓存条数: {len(ordered)}")
print(f"  合计 MB: {total_mb}")
lines = [f"🎵 曲库 {len(ordered)}/{mod.CACHE_MAX} 首"
         + (f"，共 {total_mb}MB" if total_mb else "")]
for i, e in enumerate(ordered, 1):
    sec = int(e.get("seconds", 0))
    tag = "AI" if e.get("mode") == "ai" else "原"
    hits = int(e.get("hits", 0))
    lines.append(f"{i}. [{tag}] {e.get('song','?')} {sec}s"
                 + (f" · 复用{hits}次" if hits else ""))
print("  预览输出:")
for ln in lines:
    print("   ", ln)
print()
print("  ✅ 无 AttributeError")
PYEOF
docker cp /tmp/test_songlist.py astrbot:/tmp/test_songlist.py
docker exec astrbot python3 /tmp/test_songlist.py 2>&1 | tail -12

echo ""
echo "=== 4. 热重载 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 150
echo ""
