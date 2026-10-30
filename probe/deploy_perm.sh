#!/bin/bash
set -u
echo "=== 1. 部署新版 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
echo "  已复制"

echo ""
echo "=== 2. 语法 + 导入检查 ==="
docker exec astrbot python3 /tmp/check_import2.py 2>&1 | tail -5

echo ""
echo "=== 3. 权限逻辑单元测试 ==="
cat > /tmp/test_perm.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

print("  GROUP_ACCESS =", mod.GROUP_ACCESS)
print("  COOLDOWN_USER =", mod.COOLDOWN_USER)
print("  COOLDOWN_GROUP =", mod.COOLDOWN_GROUP)
print("  MAX_SECONDS_GROUP =", mod.MAX_SECONDS_GROUP)
print("  OWNER_ID =", mod.OWNER_ID)
print()

class FakeEvent:
    def __init__(self, uid, umo="default:GroupMessage:<群号A>"):
        self._uid = uid
        self.unified_msg_origin = umo
    def get_sender_id(self):
        return self._uid

p = mod.SingPlugin.__new__(mod.SingPlugin)
print("  权限判断（以当前配置为准）:")
for uid, label in ((mod.OWNER_ID, "主人"), ("123456789", "群友")):
    ev = FakeEvent(uid)
    print(f"    {label}({uid}): owner={p._is_owner(ev)} "
          f"允许ai={not p._deny(ev,'ai')} 允许original={not p._deny(ev,'original')}")
PYEOF
docker cp /tmp/test_perm.py astrbot:/tmp/test_perm.py
docker exec astrbot python3 /tmp/test_perm.py 2>&1 | tail -20
