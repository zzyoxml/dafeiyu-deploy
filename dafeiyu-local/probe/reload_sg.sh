#!/bin/bash
set -u
echo "=== 1. 生成 JWT ==="
JWT=$(docker exec astrbot python3 /tmp/mk_jwt.py 2>/dev/null | tr -d '\r\n ')
if [ -z "$JWT" ]; then echo "  JWT 生成失败"; exit 1; fi
echo "  OK (${#JWT} 字符)"

echo ""
echo "=== 2. 重载 dsh-selfguard ==="
RESP=$(curl -s -X POST http://127.0.0.1:6185/api/plugin/reload \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"name":"dsh-selfguard"}' 2>&1)
echo "  $RESP"

echo ""
echo "=== 3. 等 5 秒看日志 ==="
sleep 5
docker logs astrbot --since 30s 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -iE "selfguard|自制力|error" | tail -8
</bash>
</invoke>
