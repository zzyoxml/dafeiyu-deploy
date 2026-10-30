#!/bin/bash
set -u
echo "=== 1. 主环境 edge-tts 版本（重建后是否回退）==="
docker exec astrbot python3 -c "import edge_tts; print('  主环境:', edge_tts.__version__)" 2>&1 | tail -2

echo ""
echo "=== 2. venv 里的 edge-tts 版本（挂载卷，应保留）==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "import edge_tts; print('  venv:', edge_tts.__version__)" 2>&1 | tail -2

echo ""
echo "=== 3. 主环境实测能否合成 ==="
docker exec astrbot python3 /tmp/test_edge.py 2>&1 | tail -3

echo ""
echo "=== 4. venv 实测能否合成 ==="
cat > /tmp/test_edge_venv.py <<'PYEOF'
import asyncio, os, sys
sys.path.insert(0, "/AstrBot/data/sing/venv/lib/python3.12/site-packages")
import edge_tts
async def main():
    print("  版本:", edge_tts.__version__)
    try:
        await edge_tts.Communicate("测试一下", "zh-CN-XiaoxiaoNeural").save("/tmp/e1.mp3")
        print("  ✅ venv 合成成功:", os.path.getsize("/tmp/e1.mp3"), "bytes")
    except Exception as e:
        print("  ❌ venv 失败:", type(e).__name__, str(e)[:120])
asyncio.run(main())
PYEOF
docker cp /tmp/test_edge_venv.py astrbot:/tmp/test_edge_venv.py
docker exec astrbot /AstrBot/data/sing/venv/bin/python /tmp/test_edge_venv.py 2>&1 | tail -4
