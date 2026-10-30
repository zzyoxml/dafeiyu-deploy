#!/bash
set -u
echo "=== 1. 重新生成 JWT ==="
cat > /tmp/mk_jwt.py <<'PYEOF'
import time, jwt
secret = "<你的JWT_SECRET>"
tok = jwt.encode({"username": "xml", "exp": int(time.time()) + 7200},
                 secret, algorithm="HS256")
print(tok)
PYEOF
JWT=$(docker exec astrbot python3 /tmp/mk_jwt.py 2>/dev/null | tail -1)
if [ -z "$JWT" ]; then
  echo "  容器内失败，试宿主机"
  JWT=$(python3 /tmp/mk_jwt.py 2>/dev/null | tail -1)
fi
echo "  JWT 长度: ${#JWT}"
echo "$JWT" > /tmp/astrbot_jwt

echo ""
echo "=== 2. 验证 token 有效 ==="
curl -s -m 10 "http://<PANEL_ADDR>/api/auth/account" -H "Authorization: Bearer $JWT" | head -c 100
echo ""

echo ""
echo "=== 3. 热重载 ==="
for p in dsh-voice dsh-voice-liuying; do
  R=$(curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
    -d "{\"name\":\"$p\"}" 2>&1 | head -c 90)
  echo "  $p → $R"
done
