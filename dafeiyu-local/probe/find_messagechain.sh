#!/bin/bash
set -u
echo "=== 1. MessageChain 正确导入位置 ==="
cat > /tmp/find_mc.py <<'PYEOF'
import astrbot.api.message_components as mc
print("  message_components 里的名字:")
for n in dir(mc):
    if not n.startswith("_"):
        print("   ", n)
PYEOF
docker cp /tmp/find_mc.py astrbot:/tmp/find_mc.py
docker exec astrbot python3 /tmp/find_mc.py 2>&1

echo ""
echo "=== 2. MessageChain 在哪 ==="
cat > /tmp/find_mc2.py <<'PYEOF'
import pkgutil, astrbot.api
for finder, name, ispkg in pkgutil.walk_packages(astrbot.api.__path__, "astrbot.api."):
    if "message" in name or "chain" in name.lower():
        print("  包:", name)
try:
    from astrbot.api.event import filter, AstrMessageEvent
    print("  event 模块 OK")
except Exception as e:
    print("  event:", e)
for path in ("astrbot.api.message_components", "astrbot.core.message", "astrbot.core.astrbot_message"):
    try:
        m = __import__(path, fromlist=["MessageChain"])
        print(f"  {path}: MessageChain =", getattr(m, "MessageChain", "无"))
    except Exception as e:
        print(f"  {path}: {type(e).__name__}")
PYEOF
docker cp /tmp/find_mc2.py astrbot:/tmp/find_mc2.py
docker exec astrbot python3 /tmp/find_mc2.py 2>&1

echo ""
echo "=== 3. 参考 dsh-voice 的完整 import 段 ==="
docker exec astrbot sh -c "head -70 /AstrBot/data/plugins/dsh-voice/main.py | grep -n 'import\|from'"
