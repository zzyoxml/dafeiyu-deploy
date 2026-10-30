#!/bin/bash
set -u
echo "=== 1. 部署 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
docker exec astrbot python3 /tmp/check_sing.py 2>&1 | grep -E "语法|导入|插件类" || \
  docker exec astrbot python3 -c "
import ast,sys
ast.parse(open('/AstrBot/data/plugins/dsh-sing/main.py',encoding='utf-8').read())
print('  语法 OK')"

echo ""
echo "=== 2. 清掉现有重复（按语义合并）==="
cat > /tmp/dedup3.py <<'PYEOF'
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

groups = {}
for k, v in sorted(entries.items(), key=lambda kv: -kv[1].get("last_used", 0)):
    sem = (v.get("song"), v.get("mode"), v.get("seconds"), v.get("start"), v.get("pitch"))
    if sem not in groups:
        groups[sem] = (k, v)      # 排过序，第一条就是最新的
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
    print(f"    {v['song']} {v['seconds']}s mode={v['mode']} hits={v.get('hits',0)} file={v['file']}")
st = mod._cache_stats()
print(f"  stats: {st['count']}/{st['max']} 首 {st['bytes']//1048576}MB")
PYEOF
docker cp /tmp/dedup3.py astrbot:/tmp/dedup3.py
docker exec astrbot python3 /tmp/dedup3.py 2>&1 | tail -10

echo ""
echo "=== 3. 用临时目录验证新代码的去重（不动真实缓存）==="
cat > /tmp/test_dedup_safe.py <<'PYEOF'
import sys, time, shutil
from pathlib import Path
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "sing", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# 指向临时目录，绝不碰真实缓存
tmp = Path("/tmp/cache-test"); shutil.rmtree(tmp, ignore_errors=True); tmp.mkdir(parents=True)
mod.CACHE_DIR = tmp
mod.CACHE_INDEX = tmp / "index.json"

fake = Path("/tmp/f.mp3"); fake.write_bytes(b"X"*2048)
k1 = mod._cache_key("测试歌","ai",30,0,0,"")
k2 = mod._cache_key("测试歌","ai",30,0,0,"某音源标题")
mod._cache_put(k1, fake, "测试歌","ai",30,0,0,"某音源标题","bilibili")
time.sleep(0.05)
mod._cache_put(k2, fake, "测试歌","ai",30,0,0,"某音源标题","bilibili")
st = mod._cache_stats()
print(f"  同语义写入2次 → 条数={st['count']} (应 1)")
print(f"  磁盘文件数: {len(list(tmp.glob('*.mp3')))} (应 1)")

# 不同时长应保留
k3 = mod._cache_key("测试歌","ai",60,0,0,"")
mod._cache_put(k3, fake, "测试歌","ai",60,0,0,"某音源标题","bilibili")
st = mod._cache_stats()
print(f"  再写入60s版本 → 条数={st['count']} (应 2)")

shutil.rmtree(tmp, ignore_errors=True); fake.unlink(missing_ok=True)
print("  ✅ 测试完成，真实缓存未受影响")
PYEOF
docker cp /tmp/test_dedup_safe.py astrbot:/tmp/test_dedup_safe.py
docker exec astrbot python3 /tmp/test_dedup_safe.py 2>&1 | tail -8

echo ""
echo "=== 4. 确认真实缓存还在 ==="
docker exec astrbot python3 -c "
import sys; sys.path.insert(0,'/AstrBot')
import importlib.util
spec = importlib.util.spec_from_file_location('sing','/AstrBot/data/plugins/dsh-sing/main.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print('  真实缓存:', m._cache_stats())" 2>&1 | tail -3

echo ""
echo "=== 5. 热重载 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 120
echo ""
