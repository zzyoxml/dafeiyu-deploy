#!/bin/bash
set -u
echo "=== 1. 重新部署 ==="
cp <PROBE_DIR>/dsh-voice-liuying/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-voice-liuying/main.py
docker exec astrbot python3 /tmp/check_vly.py 2>&1 | grep -E "语法|导入|类:"

echo ""
echo "=== 2. 就绪检查（修正后）==="
docker exec astrbot python3 /tmp/check_vly_ready.py 2>&1 | tail -8

echo ""
echo "=== 3. 真实合成测试（走插件完整函数）==="
cat > /tmp/test_vly_synth.py <<'PYEOF'
import asyncio, sys, time
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "vly", "/AstrBot/data/plugins/dsh-voice-liuying/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

async def main():
    text = "今天群里好热闹呀，我来陪你们聊会儿"
    print(f"  文本: {text} ({len(text)}字)")
    t0 = time.time()
    p = await mod._synthesize_liuying(text)
    dt = time.time() - t0
    if p:
        print(f"  ✅ 合成成功 {p.name} {p.stat().st_size//1024}KB，耗时 {dt:.1f}s")
        # 第二次应命中缓存
        t1 = time.time()
        p2 = await mod._synthesize_liuying(text)
        print(f"  缓存复用耗时 {(time.time()-t1)*1000:.0f}ms（应 <50ms）")
        print(f"  同一文件: {p2 == p}")
    else:
        print(f"  ❌ 失败，耗时 {dt:.1f}s")

asyncio.run(main())
PYEOF
docker cp /tmp/test_vly_synth.py astrbot:/tmp/test_vly_synth.py
timeout 600 docker exec astrbot python3 /tmp/test_vly_synth.py 2>&1 | tail -10
