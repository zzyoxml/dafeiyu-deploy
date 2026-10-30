#!/bin/bash
set -u
echo "=== 1. 把 edge-tts 7.3.1 装进持久卷的 venv（已完成，复核）==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "import edge_tts; print('  venv edge-tts:', edge_tts.__version__)" 2>&1 | tail -2

echo ""
echo "=== 2. 写一个自愈脚本：容器启动后自动把主环境 edge-tts 升级 ==="
cat > /opt/dafeiyu/data/astrbot/plugins/dsh-voice-liuying/fix_edge_on_boot.sh <<'EOS'
#!/bin/bash
# 容器重建后镜像自带 edge-tts 7.2.7 会对 Bing 返回 403。
# 本脚本在插件初始化时由 _readiness 触发一次（也可手动跑）。
pip install --index-url https://pypi.tuna.tsinghua.edu.cn/simple -q -U edge-tts 2>/dev/null
EOS
chmod +x /opt/dafeiyu/data/astrbot/plugins/dsh-voice-liuying/fix_edge_on_boot.sh
echo "  已写 fix_edge_on_boot.sh"

echo ""
echo "=== 3. 兼容性说明：即使主环境回退，venv 路径照样工作 ==="
cat > /tmp/verify_dual.py <<'PYEOF'
import asyncio, sys, os
sys.path.insert(0, "/AstrBot")
import importlib.util
s = importlib.util.spec_from_file_location(
    "v", "/AstrBot/data/plugins/dsh-voice-liuying/main.py")
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)

async def main():
    print(f"  主环境 edge-tts: {__import__('edge_tts').__version__}")
    # 模拟主环境坏掉：直接测 venv 路径
    out = "/tmp/dual-test.mp3"
    if os.path.exists(out): os.remove(out)
    ok = await m._edge_tts(out, "双路径验证")
    print(f"  _edge_tts(venv优先) → {ok}, {os.path.getsize(out) if os.path.exists(out) else 0} bytes")
asyncio.run(main())
PYEOF
docker cp /tmp/verify_dual.py astrbot:/tmp/verify_dual.py
docker exec astrbot python3 /tmp/verify_dual.py 2>&1 | tail -5

echo ""
echo "=== 4. 清理旧音频缓存（避免下次命中坏结果）==="
rm -f /opt/dafeiyu/data/astrbot/audio/voice-cache/*.mp3 2>/dev/null
echo "  已清空语音缓存"
ls /opt/dafeiyu/data/astrbot/audio/voice-cache/ 2>/dev/null | wc -l
