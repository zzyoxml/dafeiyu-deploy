#!/bin/bash
set -u
echo "=== 1. voice-ly 的钩子是否正确注册（on_llm_response）==="
docker exec astrbot python3 - <<'PYEOF' 2>&1 | tail -20
import ast
src = open("/AstrBot/data/plugins/dsh-voice-liuying/main.py", encoding="utf-8").read()
tree = ast.parse(src)
cls = next(n for n in tree.body if isinstance(n, ast.ClassDef))
for n in cls.body:
    if isinstance(n, ast.AsyncFunctionDef):
        decos = []
        for d in n.decorator_list:
            if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute):
                decos.append(d.func.attr)
            elif isinstance(d, ast.Attribute):
                decos.append(d.attr)
        print(f"  {n.name:20} ← {decos}")
PYEOF

echo ""
echo "=== 2. reply-guard 的钩子 ==="
docker exec astrbot python3 - <<'PYEOF' 2>&1 | tail -15
import ast
src = open("/AstrBot/data/plugins/dsh-reply-guard/main.py", encoding="utf-8").read()
tree = ast.parse(src)
cls = next(n for n in tree.body if isinstance(n, ast.ClassDef))
for n in cls.body:
    if isinstance(n, ast.AsyncFunctionDef):
        decos = []
        for d in n.decorator_list:
            if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute):
                arg = ast.unparse(d.args[0])[:30] if d.args else ""
                decos.append(f"{d.func.attr}({arg})")
            elif isinstance(d, ast.Attribute):
                decos.append(d.attr)
        print(f"  {n.name:20} ← {decos}")
PYEOF

echo ""
echo "=== 3. voice-ly 的 20% 概率是否被冷却挡住（当前状态）==="
docker exec astrbot python3 - <<'PYEOF' 2>&1 | tail -8
import sys, time
sys.path.insert(0, "/AstrBot")
import importlib.util
s = importlib.util.spec_from_file_location("v", "/AstrBot/data/plugins/dsh-voice-liuying/main.py")
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
print(f"  AUTO_RATE = {m.AUTO_RATE}")
print(f"  COOLDOWN = {m.COOLDOWN}s, HOURLY_CAP = {m.HOURLY_CAP}")
print(f"  _allow_now() = {m._allow_now()}（新进程状态干净，应 True）")
print(f"  _keep_for_voice('今天天气不错呀') = {m._keep_for_voice('今天天气不错呀')}")
PYEOF
