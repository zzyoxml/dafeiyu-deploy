#!/bin/bash
set -u
echo "=== 1. 安装插件 ==="
mkdir -p /opt/dafeiyu/data/astrbot/plugins/dsh-voice-liuying
cp /mnt/d/xml/dafeiyu/dafeiyu-local/probe/dsh-voice-liuying/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-voice-liuying/main.py
cp /mnt/d/xml/dafeiyu/dafeiyu-local/probe/dsh-voice-liuying/metadata.yaml \
   /opt/dafeiyu/data/astrbot/plugins/dsh-voice-liuying/metadata.yaml
echo "  已复制"

echo ""
echo "=== 2. 语法 + 导入检查 ==="
cat > /tmp/check_vly.py <<'PYEOF'
import ast, sys
p = "/AstrBot/data/plugins/dsh-voice-liuying/main.py"
try:
    ast.parse(open(p, encoding="utf-8").read())
    print("  语法 OK")
except SyntaxError as e:
    print(f"  ❌ 语法错误 line {e.lineno}: {e.msg}")
    raise SystemExit(1)

sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location("vly", p)
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
    print("  ✅ 导入成功")
    print("  类:", [n for n in dir(mod) if n.endswith("Plugin")])
except Exception as e:
    import traceback
    print("  ❌ 导入失败:", type(e).__name__, e)
    traceback.print_exc()
PYEOF
docker cp /tmp/check_vly.py astrbot:/tmp/check_vly.py
docker exec astrbot python3 /tmp/check_vly.py 2>&1 | tail -10

echo ""
echo "=== 3. 纯逻辑单元测试（不跑模型）==="
cat > /tmp/test_vly.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "vly", "/AstrBot/data/plugins/dsh-voice-liuying/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

print("  配置: 概率=%.0f%% 最长=%d字 冷却=%ds 小时=%d" % (
    mod.AUTO_RATE*100, mod.MAX_CHARS, mod.COOLDOWN, mod.HOURLY_CAP))
print()
print("  _keep_for_voice 判定:")
cases = [
    ("今天天气不错呀", True),
    ("你好", False),                       # 太短
    ("好的", False),                       # 太短
    ("😀😀😀", False),                     # 无文字
    ("/唱歌状态", False),                   # 命令
    ("🎤 唱歌链路自检", False),             # 自检
    ("这个群里今天来了好多人啊，好热闹", True),
    ("一" * 60, False),                    # 太长
]
for t, want in cases:
    got = mod._keep_for_voice(t)
    ok = "✅" if got == want else "❌"
    print(f"    {ok} {t[:28]!r:32} → {got} (应 {want})")

print()
print("  _norm 归一化:")
for t in ["**你好** 呀", "你好   呀", "`代码`"]:
    print(f"    {t!r:16} → {mod._norm(t)!r}")
PYEOF
docker cp /tmp/test_vly.py astrbot:/tmp/test_vly.py
docker exec astrbot python3 /tmp/test_vly.py 2>&1 | tail -20
