#!/bash
set -u
echo "=== 用框架注册表实时查询（在主进程内做不到，改用持久化探针）==="
cat > /tmp/probe_registry.py <<'PYEOF'
"""在插件被加载后，把注册表快照写到文件，避免只能在进程内看。"""
import json, sys, time
sys.path.insert(0, "/AstrBot")

out = "/AstrBot/data/sing/registry.json"

def snapshot():
    from astrbot.core.star.star_handler import star_handlers_registry
    rows = []
    for md in star_handlers_registry:
        mp = str(getattr(md, "module_path", "") or "")
        if "dsh-sing" not in mp:
            continue
        fs = getattr(md, "event_filters", []) or []
        rows.append({
            "handler": getattr(md, "handler_name", "?"),
            "filters": [type(f).__name__ for f in fs],
            "regex": [getattr(f, "regex_str", "") for f in fs
                      if hasattr(f, "regex_str")],
        })
    return rows

# 独立进程里注册表是空的，这是预期；关键看主进程日志。
rows = snapshot()
print(f"  独立进程注册表条数: {len(rows)}（预期 0，仅供确认 API 可用）")
print("  API 可用:", hasattr(__import__('astrbot.core.star.star_handler', fromlist=['x']), 'star_handlers_registry'))
PYEOF
docker cp /tmp/probe_registry.py astrbot:/tmp/probe_registry.py
docker exec astrbot python3 /tmp/probe_registry.py 2>&1 | tail -4

echo ""
echo "=== 关键验证：直接发一条「选 1」看是否被 cmd_pick 接住 ==="
echo "  先看当前 status.jsonl 尾部（作为基线）"
tail -2 /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null | sed 's/^/    /'

echo ""
echo "=== 检查是否有语法上被吞掉的情况（缩进/装饰器顺序）==="
docker exec astrbot python3 - <<'PYEOF'
import ast
src = open("/AstrBot/data/plugins/dsh-sing/main.py", encoding="utf-8").read()
tree = ast.parse(src)
cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == "SingPlugin")
print("  SingPlugin 里的方法:")
for n in cls.body:
    if isinstance(n, (ast.AsyncFunctionDef, ast.FunctionDef)):
        decos = []
        for d in n.decorator_list:
            if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute):
                decos.append(f"{d.func.attr}({ast.unparse(d.args[0])[:40] if d.args else ''})")
            elif isinstance(d, ast.Attribute):
                decos.append(d.attr)
        print(f"    {n.name}: {decos}")
PYEOF
