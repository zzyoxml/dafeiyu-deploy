#!/bin/bash
set -u
echo "=== 1. 测试 B 站搜索（插件用的接口）==="
cat > /tmp/test_search.py <<'PYEOF'
import json, sys, urllib.parse, urllib.request
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
q = "夜曲 周杰伦"
url = f"https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword={urllib.parse.quote(q)}&page=1"
req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": "https://www.bilibili.com/"})
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.loads(r.read().decode("utf-8", "ignore"))
    print("  code:", data.get("code"))
    results = (data.get("data") or {}).get("result") or []
    print("  结果数:", len(results))
    for i, item in enumerate(results[:5], 1):
        import re
        title = re.sub(r"<[^>]+>", "", str(item.get("title", "")))
        print(f"  {i}. {title[:50]}  [{item.get('duration')}]  bvid={item.get('bvid')}")
except Exception as e:
    print("  搜索失败:", type(e).__name__, str(e)[:150])
PYEOF
docker cp /tmp/test_search.py astrbot:/tmp/test_search.py
docker exec astrbot python3 /tmp/test_search.py 2>&1

echo ""
echo "=== 2. 测试 yt-dlp 下载音频 ==="
docker exec astrbot sh -c "cd /tmp && rm -f dl-test* && /AstrBot/data/sing/venv/bin/yt-dlp --no-warnings -f 'bestaudio/best' -x --audio-format mp3 -o 'dl-test.%(ext)s' --no-playlist 'https://www.bilibili.com/video/BV1Wx411L7bC' 2>&1 | tail -8"
echo ""
docker exec astrbot sh -c "ls -la /tmp/dl-test* 2>/dev/null || echo '  下载失败'"
