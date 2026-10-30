#!/bin/bash
set -u
echo "=== 1. 安装 dsh-reply-guard ==="
mkdir -p /opt/dafeiyu/data/astrbot/plugins/dsh-reply-guard
cp <PROBE_DIR>/dsh-reply-guard/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-reply-guard/main.py
cp <PROBE_DIR>/dsh-reply-guard/metadata.yaml \
   /opt/dafeiyu/data/astrbot/plugins/dsh-reply-guard/metadata.yaml
echo "  已复制"

echo ""
echo "=== 2. 语法 + 导入 ==="
cat > /tmp/check_guard.py <<'PYEOF'
import ast, sys
p = "/AstrBot/data/plugins/dsh-reply-guard/main.py"
try:
    ast.parse(open(p, encoding="utf-8").read())
    print("  语法 OK")
except SyntaxError as e:
    print(f"  ❌ 语法错误 line {e.lineno}: {e.msg}")
    raise SystemExit(1)
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location("guard", p)
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
docker cp /tmp/check_guard.py astrbot:/tmp/check_guard.py
docker exec astrbot python3 /tmp/check_guard.py 2>&1 | tail -8

echo ""
echo "=== 3. 限流逻辑单元测试 ==="
cat > /tmp/test_guard.py <<'PYEOF'
import sys, time
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "guard", "/AstrBot/data/plugins/dsh-reply-guard/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

print("  配置: %d条/%ds" % (mod.RATE_MAX, mod.RATE_WINDOW))
print()

# 模拟连发 13 条
print("  连发 13 条，验证第 11 条起被拦:")
allowed = 0
blocked = 0
for i in range(1, 14):
    ok = mod._rate_take("default:GroupMessage:<群号A>")
    if ok: allowed += 1
    else: blocked += 1
    print(f"    第{i:2d}条 → {'允许' if ok else '拦截'}")
print(f"  结果: 允许 {allowed} 条，拦截 {blocked} 条（应 10/3）")
print(f"  剩余额度: {mod._rate_left('default:GroupMessage:<群号A>')} (应 0)")
print()

# 不同会话互不影响
print("  不同会话隔离:")
a = mod._rate_take("umo-A")
b = mod._rate_take("umo-B")
print(f"    两个不同会话各自第一条: A={a} B={b} (应都是 True)")
print()

# _named 判定
print("  点名判定:")
for t, want in [("@小鲸鱼 /唱歌", True), ("小鲸鱼你在吗", True),
                ("今天好热", False), ("鲸鱼", True), ("<BOT_QQ>", True)]:
    got = mod._named(t)
    print(f"    {'✅' if got==want else '❌'} {t!r:22} → {got} (应 {want})")
PYEOF
docker cp /tmp/test_guard.py astrbot:/tmp/test_guard.py
docker exec astrbot python3 /tmp/test_guard.py 2>&1 | tail -30
