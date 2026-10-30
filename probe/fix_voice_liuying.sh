#!/bash
set -u
echo "=== 1. 打补丁：dsh-voice 接入流萤音色 ==="
cp <PROBE_DIR>/patch_voice_liuying.py /tmp/pvl.py
python3 /tmp/pvl.py

echo ""
echo "=== 2. 导入 + 函数存在性 ==="
docker cp /opt/dafeiyu/data/astrbot/plugins/dsh-voice/main.py astrbot:/tmp/dv2.py
docker exec astrbot python3 -c "
import sys; sys.path.insert(0,'/AstrBot')
import importlib.util
s=importlib.util.spec_from_file_location('dv2','/tmp/dv2.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
print('  ✅ 导入成功')
print('  _liuying_convert:', callable(m._liuying_convert))
print('  _edge_tts_once:', callable(m._edge_tts_once))
" 2>&1 | tail -4

echo ""
echo "=== 3. 实测完整链路：Edge → RVC 流萤 ==="
cat > /tmp/test_dv_liu.py <<'PYEOF'
import asyncio, sys, time, wave, contextlib
sys.path.insert(0, "/AstrBot")
import importlib.util
s = importlib.util.spec_from_file_location("dv2", "/tmp/dv2.py")
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)

async def main():
    t0 = time.time()
    audio, err = await m._edge_tts_once("你好呀，我是小鲸鱼")
    dt = time.time() - t0
    if audio:
        print(f"  ✅ 合成+变声成功 {len(audio)}B，耗时 {dt:.1f}s")
    else:
        print(f"  ❌ 失败: {err[:150]}")
asyncio.run(main())
PYEOF
docker cp /tmp/test_dv_liu.py astrbot:/tmp/test_dv_liu.py
timeout 400 docker exec astrbot python3 /tmp/test_dv_liu.py 2>&1 | tail -8
