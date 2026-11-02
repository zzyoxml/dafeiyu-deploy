#!/bin/bash
set -u
D=/opt/dafeiyu/data/astrbot/plugins/dsh-stt-clean

echo "=== 1. 修 metadata 版本 ==="
python3 - <<'PYEOF'
from pathlib import Path
p = Path("/opt/dafeiyu/data/astrbot/plugins/dsh-stt-clean/metadata.yaml")
s = p.read_text(encoding="utf-8")
s = s.replace("version: 1.0.0", "version: 1.0.1")
p.write_text(s, encoding="utf-8")
print("  " + [l for l in s.splitlines() if "version" in l][0])
PYEOF

echo ""
echo "=== 2. 确认文件内容与本地一致 ==="
grep -c "TAG_FULL_RE" "$D/main.py" | xargs -I{} echo "  TAG_FULL_RE 出现 {} 次（应为 2）"
grep -n "1.0.1" "$D/main.py" | head -2 | sed 's/^/  /'

echo ""
echo "=== 3. 热重载 ==="
JWT=$(docker exec astrbot python3 /tmp/mk_jwt.py 2>/dev/null | tr -d '\r\n')
if [ -z "$JWT" ]; then
  echo "  ⚠ JWT 生成失败，重启代替"
  docker restart astrbot >/dev/null 2>&1
else
  curl -s -m 20 -X POST http://127.0.0.1:6185/api/plugin/reload \
    -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
    -d '{"name":"dsh-stt-clean"}' | head -3
  echo ""
fi
sleep 5
docker logs astrbot --since 40s 2>&1 | grep -i "stt-clean" | tail -3
