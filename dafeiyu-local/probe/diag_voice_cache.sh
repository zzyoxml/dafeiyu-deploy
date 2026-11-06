#!/bin/bash
set -u
echo "=== 1. Edge TTS 403 复现（容器内直测）==="
cat > /tmp/test_edge.py <<'PYEOF'
import asyncio, sys
try:
    import edge_tts
    print("  edge-tts 版本:", edge_tts.__version__ if hasattr(edge_tts,'__version__') else "未知")
except Exception as e:
    print("  导入失败:", e)
    sys.exit(1)

async def main():
    import edge_tts
    try:
        c = edge_tts.Communicate("你好，我是小鲸鱼", "zh-CN-XiaoxiaoNeural")
        await c.save("/tmp/edge-test.mp3")
        import os
        print("  ✅ 合成成功:", os.path.getsize("/tmp/edge-test.mp3"), "bytes")
    except Exception as e:
        print("  ❌ 失败:", type(e).__name__, str(e)[:300])

asyncio.run(main())
PYEOF
docker cp /tmp/test_edge.py astrbot:/tmp/test_edge.py
docker exec astrbot python3 /tmp/test_edge.py 2>&1 | tail -6

echo ""
echo "=== 2. 检查 Edge TTS 的 Sec-MS-GEC 版本常量 ==="
docker exec astrbot sh -c "grep -rn 'SEC_MS_GEC_VERSION\|3650' /usr/local/lib/python3.12/site-packages/edge_tts/*.py 2>/dev/null | head -5"

echo ""
echo "=== 3. 容器时间是否准确（GEC token 依赖时钟）==="
echo "  容器: $(docker exec astrbot date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "  宿主机: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "=== 4. 现有防刷/限流插件 ==="
docker exec astrbot sh -c "ls /AstrBot/data/plugins/ | grep -iE 'rate|limit|spam|flood|ctx|guard|anti'"

echo ""
echo "=== 5. 检查插件 metadata 里是否有类似功能 ==="
docker exec astrbot sh -c "grep -l '每分钟\|频率\|条数\|刷屏' /AstrBot/data/plugins/*/metadata.yaml 2>/dev/null | head -5"
