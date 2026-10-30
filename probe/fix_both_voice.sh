#!/bin/bash
set -u
echo "=== 1. 打补丁到 dsh-voice ==="
cp <PROBE_DIR>/patch_old_voice.py /tmp/patch_old_voice.py
python3 /tmp/patch_old_voice.py

echo ""
echo "=== 2. 导入校验 ==="
docker cp /opt/dafeiyu/data/astrbot/plugins/dsh-voice/main.py astrbot:/tmp/dv.py
docker exec astrbot python3 -c "
import sys; sys.path.insert(0,'/AstrBot')
import importlib.util
s=importlib.util.spec_from_file_location('dv','/tmp/dv.py')
m=importlib.util.module_from_spec(s)
try:
    s.loader.exec_module(m)
    print('  ✅ 导入成功')
    print('  _edge_tts_once:', callable(m._edge_tts_once))
except Exception as e:
    print('  ❌', type(e).__name__, e)
" 2>&1 | tail -4

echo ""
echo "=== 3. 实测 dsh-voice 的 _edge_tts_once ==="
cat > /tmp/test_dv_edge.py <<'PYEOF'
import asyncio, sys
sys.path.insert(0, "/AstrBot")
import importlib.util
s = importlib.util.spec_from_file_location("dv", "/tmp/dv.py")
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)

async def main():
    audio, err = await m._edge_tts_once("语音测试一二三")
    if audio:
        print(f"  ✅ 成功 {len(audio)} bytes")
    else:
        print(f"  ❌ 失败: {err[:120]}")
asyncio.run(main())
PYEOF
docker cp /tmp/test_dv_edge.py astrbot:/tmp/test_dv_edge.py
timeout 120 docker exec astrbot python3 /tmp/test_dv_edge.py 2>&1 | tail -5

echo ""
echo "=== 4. 热重载两个语音插件 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
for p in dsh-voice dsh-voice-liuying; do
  R=$(curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
    -d "{\"name\":\"$p\"}" 2>&1 | head -c 100)
  echo "  $p → $R"
done
