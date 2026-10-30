#!/bin/bash
set -u
echo "=== 1. 复制修正后的插件 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
echo "  已更新"

echo ""
echo "=== 2. 语法与导入测试 ==="
cat > /tmp/check_import2.py <<'PYEOF'
import ast
p = "/AstrBot/data/plugins/dsh-sing/main.py"
ast.parse(open(p, encoding="utf-8").read())
print("  语法 OK")

import importlib.util, sys
sys.path.insert(0, "/AstrBot")
spec = importlib.util.spec_from_file_location("dsh_sing_main", p)
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
    print("  ✅ 导入成功")
    print("  插件类:", [n for n in dir(mod) if n.endswith("Plugin")])
except Exception as e:
    import traceback
    print("  ❌ 导入失败:", type(e).__name__, e)
    traceback.print_exc()
PYEOF
docker cp /tmp/check_import2.py astrbot:/tmp/check_import2.py
docker exec astrbot python3 /tmp/check_import2.py 2>&1 | tail -15

echo ""
echo "=== 3. 多个 @filter.command 叠加是否合法（看 dsh 其他插件示例）==="
docker exec astrbot sh -c "grep -rn -B2 -A2 '@filter.command' /AstrBot/data/plugins/dsh-imagegen/main.py 2>/dev/null | head -25"
