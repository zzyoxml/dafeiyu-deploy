#!/bash
set -u
echo "=== 1. 部署 voice-liuying 修复版 ==="
cp /mnt/d/xml/dafeiyu/dafeiyu-local/probe/dsh-voice-liuying/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-voice-liuying/main.py

echo ""
echo "=== 2. 语法 + 导入 ==="
docker exec astrbot python3 -c "
import ast
ast.parse(open('/AstrBot/data/plugins/dsh-voice-liuying/main.py',encoding='utf-8').read())
print('  语法 OK')
import sys; sys.path.insert(0,'/AstrBot')
import importlib.util
s=importlib.util.spec_from_file_location('v','/AstrBot/data/plugins/dsh-voice-liuying/main.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
print('  ✅ 导入成功')
print('  _edge_tts 存在:', callable(m._edge_tts))
" 2>&1 | tail -5

echo ""
echo "=== 3. 实测 _edge_tts（关键）==="
docker cp /mnt/d/xml/dafeiyu/dafeiyu-local/probe/test_edge_fn.py astrbot:/tmp/test_edge_fn.py 2>/dev/null || cat > /tmp/test_edge_fn.py <<'PYEOF'
import asyncio, sys, os
sys.path.insert(0, "/AstrBot")
import importlib.util
s = importlib.util.spec_from_file_location(
    "v", "/AstrBot/data/plugins/dsh-voice-liuying/main.py")
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)

async def main():
    out = "/tmp/edge-fn-test.mp3"
    if os.path.exists(out): os.remove(out)
    ok = await m._edge_tts(out, "语音测试")
    sz = os.path.getsize(out) if os.path.exists(out) else 0
    print(f"  _edge_tts 返回: {ok}, 文件 {sz} bytes")
asyncio.run(main())
PYEOF
docker cp /tmp/test_edge_fn.py astrbot:/tmp/test_edge_fn.py
docker exec astrbot python3 /tmp/test_edge_fn.py 2>&1 | tail -6
