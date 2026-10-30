#!/bin/bash
set -u
echo "=== 1. 语法 + 导入检查 ==="
cat > /tmp/check_sing.py <<'PYEOF'
import ast, sys
p = "/AstrBot/data/plugins/dsh-sing/main.py"
try:
    ast.parse(open(p, encoding="utf-8").read())
    print("  语法 OK")
except SyntaxError as e:
    print(f"  ❌ 语法错误 line {e.lineno}: {e.msg}")
    raise SystemExit(1)

sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location("dsh_sing_main", p)
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
    print("  ✅ 导入成功")
    print("  插件类:", [n for n in dir(mod) if n.endswith("Plugin")])
except Exception as e:
    import traceback
    print("  ❌ 导入失败:", type(e).__name__, e)
    traceback.print_exc()
    raise SystemExit(1)

print()
print("  进度持久化检查:")
print("    STATUS_FILE =", mod.STATUS_FILE)
print("    _read_last_status() =", mod._read_last_status())
print("    _busy_lock().locked() =", mod._busy_lock().locked())
PYEOF
docker cp /tmp/check_sing.py astrbot:/tmp/check_sing.py
docker exec astrbot python3 /tmp/check_sing.py 2>&1 | tail -12

echo ""
echo "=== 2. 拿 AstrBot JWT（用于热重载）==="
cat > /tmp/mk_jwt.py <<'PYEOF'
import hashlib, hmac, json, base64, time
def b64(x): return base64.urlsafe_b64encode(x).rstrip(b"=")
secret = "<你的JWT_SECRET>"
h = b64(json.dumps({"alg":"HS256","typ":"JWT"},separators=(",",":")).encode())
p = b64(json.dumps({"username":"xml","exp":int(time.time())+3600},separators=(",",":")).encode())
sig = b64(hmac.new(secret.encode(), h+b"."+p, hashlib.sha256).digest())
print((h+b"."+p+b"."+sig).decode())
PYEOF
docker cp /tmp/mk_jwt.py astrbot:/tmp/mk_jwt.py
JWT=$(docker exec astrbot python3 /tmp/mk_jwt.py 2>/dev/null | tr -d "\r\n ")
echo "  JWT 长度: ${#JWT}"
echo "$JWT" > /tmp/astrbot_jwt

echo ""
echo "=== 3. 热重载 dsh-sing ==="
curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 400
echo ""
