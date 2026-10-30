import json, hmac, hashlib, base64, time

def b64u(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

secret = "<你的JWT_SECRET>"
now = int(time.time())
# AstrBot 默认鉴权声明：role=system_owner（对齐 require_system_scope 的 system scope）
payload = {
    "sub": "xml",
    "role": "system_owner",
    "scope": "system",
    "iat": now,
    "exp": now + 1800,
}
head = b64u(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
body = b64u(json.dumps(payload, separators=(",", ":")).encode())
sig = b64u(hmac.new(secret.encode(), f"{head}.{body}".encode(), hashlib.sha256).digest())
print(f"{head}.{body}.{sig}")
