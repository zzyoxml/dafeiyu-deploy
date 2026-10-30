#!/bin/bash
set -u

echo "=== 补装 RVC 缺失依赖 ==="
echo "  已知缺失: wget"
docker exec astrbot /AstrBot/data/sing/venv/bin/python -m pip install \
  --index-url https://pypi.tuna.tsinghua.edu.cn/simple \
  -q wget 2>&1 | tail -3

echo ""
echo "=== 检查 RVC 还缺什么 import ==="
cat > /tmp/check_imports.py <<'PYEOF'
import ast, sys, os

# 扫描 rvc_cli 里所有顶层 import，找出第三方模块
base = "/AstrBot/data/sing/rvc_cli"
mods = set()
for root, _, files in os.walk(base):
    for f in files:
        if not f.endswith(".py"):
            continue
        p = os.path.join(root, f)
        try:
            tree = ast.parse(open(p, encoding="utf-8", errors="ignore").read())
        except Exception:
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for a in node.names:
                    mods.add(a.name.split(".")[0])
            elif isinstance(node, ast.ImportFrom):
                if node.level == 0 and node.module:
                    mods.add(node.module.split(".")[0])

stdlib = set(sys.stdlib_module_names)
third = sorted(m for m in mods if m not in stdlib and m not in ("rvc_cli",))
print("  第三方模块:", third)

missing = []
for m in third:
    try:
        __import__(m)
    except ImportError:
        missing.append(m)
print("  缺失:", missing if missing else "无")
PYEOF
docker cp /tmp/check_imports.py astrbot:/tmp/check_imports.py
docker exec astrbot /AstrBot/data/sing/venv/bin/python /tmp/check_imports.py 2>&1

echo ""
echo "=== 再跑一次 cover.py ==="
timeout 900 docker exec astrbot /AstrBot/data/sing/venv/bin/python \
  /AstrBot/data/sing/cover.py /tmp/test-tone.wav /tmp/test-rvc-out.wav 0 rmvpe 2>&1 | tail -20

echo ""
docker exec astrbot sh -c "ls -la /tmp/test-rvc-out.wav 2>/dev/null || echo '  ❌ 仍无输出'"
