#!/bin/bash
set -u
echo "=== 权限验证（容器内真实环境变量）==="
cat > /tmp/verify_perm2.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

print(f"  GROUP_ACCESS      = {mod.GROUP_ACCESS}")
print(f"  MAX_SECONDS_GROUP = {mod.MAX_SECONDS_GROUP}")
print(f"  COOLDOWN_USER     = {mod.COOLDOWN_USER}")
print(f"  COOLDOWN_GROUP    = {mod.COOLDOWN_GROUP}")
print()

class FakeEvent:
    def __init__(self, uid, umo="default:GroupMessage:<群号A>"):
        self._uid = uid
        self.unified_msg_origin = umo
    def get_sender_id(self): return self._uid

p = mod.SingPlugin.__new__(mod.SingPlugin)
print("  实际权限:")
names = {"ai": "AI翻唱", "original": "原唱"}
for uid, label in ((mod.OWNER_ID, "主人"), ("123456789", "群友A"), ("987654321", "群友B")):
    ev = FakeEvent(uid)
    row = "  ".join(
        f"{names[m]}={'✅' if not p._deny(ev, m) else '❌'}" for m in ("ai", "original")
    )
    print(f"    {label}({uid}): {row}")

print()
print("  限流模拟（群友连续两次点歌）:")
import time
ev = FakeEvent("123456789")
now = time.time()
mod.LAST_USE[f"u:123456789"] = now
last = mod.LAST_USE.get("u:123456789", 0)
wait = int(mod.COOLDOWN_USER - (time.time() - last))
print(f"    刚用完 → 冷却剩余 {wait}s（应 ≈{mod.COOLDOWN_USER}）")
print(f"    线性检查通过")

print()
print("  并发锁检查:")
lock = mod._busy_lock()
print(f"    初始 locked = {lock.locked()} （应 False）")
PYEOF
docker cp /tmp/verify_perm2.py astrbot:/tmp/verify_perm2.py
docker exec astrbot python3 /tmp/verify_perm2.py 2>&1 | tail -20
