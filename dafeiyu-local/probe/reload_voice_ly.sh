#!/bin/bash
set -u
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
echo "=== 1. 热重载 dsh-voice-liuying ==="
curl -s -m 30 -X POST "http://127.0.0.1:6185/api/plugin/reload" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-voice-liuying"}' 2>&1 | head -c 300
echo ""

echo "=== 2. 加载日志 ==="
sleep 3
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "dsh-voice-liuying|\[voice-ly\]" | tail -8

echo ""
echo "=== 3. 环境就绪检查 ==="
cat > /tmp/check_vly_ready.py <<'PYEOF'
import asyncio, sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "vly", "/AstrBot/data/plugins/dsh-voice-liuying/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

async def main():
    r = await mod._readiness()
    print("  就绪检查:")
    for k, v in r.items():
        print(f"    {'✅' if v else '❌'} {k}")
    print(f"  全部就绪: {all(r.values())}")
asyncio.run(main())
PYEOF
docker cp /tmp/check_vly_ready.py astrbot:/tmp/check_vly_ready.py
docker exec astrbot python3 /tmp/check_vly_ready.py 2>&1 | tail -10
