#!/bash
set -u
echo "=== 1. 部署 + 校验 ==="
cp /mnt/d/xml/dafeiyu/dafeiyu-local/probe/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
docker exec astrbot python3 /tmp/check_sing.py 2>&1 | grep -E "语法|导入|插件类|错误"

echo ""
echo "=== 2. 清掉重复缓存并重建（只留一条）==="
cat > /tmp/dedup_cache.py <<'PYEOF'
import sys
from pathlib import Path
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

data = mod._cache_load()
entries = data.get("entries") or {}
print(f"  去重前: {len(entries)} 条")
for k, v in entries.items():
    print(f"    {k} → {v['file']} ({v['song']})")

# 按 file 去重，保留 last_used 最大的
by_file = {}
for k, v in entries.items():
    f = v.get("file")
    if f not in by_file or v.get("last_used", 0) > by_file[f][1].get("last_used", 0):
        by_file[f] = (k, v)

new_entries = {k: v for k, v in by_file.values()}
data["entries"] = new_entries
mod._cache_save(data)
print(f"  去重后: {len(new_entries)} 条")
for k, v in new_entries.items():
    print(f"    {k} → {v['file']} ({v['song']})")
print()
print(f"  stats: {mod._cache_stats()}")
PYEOF
docker cp /tmp/dedup_cache.py astrbot:/tmp/dedup_cache.py
docker exec astrbot python3 /tmp/dedup_cache.py 2>&1 | tail -12

echo ""
echo "=== 3. 热重载 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
curl -s -m 30 -X POST "http://127.0.0.1:6185/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 120
echo ""
