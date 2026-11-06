#!/bin/bash
set -u
echo "=== 用 AST 列出 SingPlugin 全部方法与装饰器 ==="
cat > /tmp/ast_deco.py <<'PYEOF'
import ast
src = open("/AstrBot/data/plugins/dsh-sing/main.py", encoding="utf-8").read()
tree = ast.parse(src)
cls = next(n for n in tree.body
           if isinstance(n, ast.ClassDef) and n.name == "SingPlugin")
print(f"  SingPlugin 共 {len(cls.body)} 个语句:")
for n in cls.body:
    if isinstance(n, (ast.AsyncFunctionDef, ast.FunctionDef)):
        decos = []
        for d in n.decorator_list:
            if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute):
                arg = ast.unparse(d.args[0])[:45] if d.args else ""
                decos.append(f"{d.func.attr}({arg})")
            elif isinstance(d, ast.Attribute):
                decos.append(d.attr)
            else:
                decos.append(ast.unparse(d)[:45])
        print(f"    {n.name:16} ← {decos}")
PYEOF
docker cp /tmp/ast_deco.py astrbot:/tmp/ast_deco.py
docker exec astrbot python3 /tmp/ast_deco.py 2>&1 | tail -15
