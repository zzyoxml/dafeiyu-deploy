#!/bin/bash
set -u
echo "=== 1. 部署 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
docker exec astrbot python3 /tmp/check_import2.py 2>&1 | tail -4

echo ""
echo "=== 2. 测搜索（带 cookie 修复）==="
cat > /tmp/test_search2.py <<'PYEOF'
import asyncio, sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

async def main():
    print("  yt-dlp 路径:", mod.YTDLP or "(空)")
    print("  ffmpeg 路径:", mod.FFMPEG or "(空)")
    print()
    for q in ("夜曲", "周杰伦 稻香"):
        print(f"--- 搜索「{q}」 ---")
        try:
            rs = await mod._search_songs(q, 4)
            for i, r in enumerate(rs, 1):
                print(f"  {i}. {r['title'][:45]}")
                print(f"     {r['url']}  [{r['duration']}s]")
        except Exception as e:
            print("  ❌ 失败:", str(e)[:200])
        print()

asyncio.run(main())
PYEOF
docker cp /tmp/test_search2.py astrbot:/tmp/test_search2.py
docker exec astrbot python3 /tmp/test_search2.py 2>&1 | tail -30
