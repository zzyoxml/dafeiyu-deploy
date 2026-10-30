import ast
import sys


def show(path, label, limit=None):
    src = open(path, encoding="utf-8").read()
    tree = ast.parse(src)
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef))
    print(f"  {label}:")
    for n in cls.body:
        if isinstance(n, ast.AsyncFunctionDef):
            decos = []
            for d in n.decorator_list:
                if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute):
                    arg = ast.unparse(d.args[0])[:34] if d.args else ""
                    decos.append(f"{d.func.attr}({arg})")
                elif isinstance(d, ast.Attribute):
                    decos.append(d.attr)
                else:
                    decos.append(ast.unparse(d)[:34])
            print(f"    {n.name:18} ← {decos}")
    print()


show("/AstrBot/data/plugins/dsh-voice-liuying/main.py", "dsh-voice-liuying")
show("/AstrBot/data/plugins/dsh-reply-guard/main.py", "dsh-reply-guard")

# voice-ly 概率逻辑自检
sys.path.insert(0, "/AstrBot")
import importlib.util
s = importlib.util.spec_from_file_location(
    "v", "/AstrBot/data/plugins/dsh-voice-liuying/main.py")
m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)
print("  voice-ly 运行参数:")
print(f"    AUTO_RATE={m.AUTO_RATE}  COOLDOWN={m.COOLDOWN}s  HOURLY={m.HOURLY_CAP}")
print(f"    _allow_now() = {m._allow_now()}  (新进程应 True)")
print(f"    _keep_for_voice('今天天气不错呀') = {m._keep_for_voice('今天天气不错呀')}")
print(f"    _keep_for_voice('/唱歌状态')     = {m._keep_for_voice('/唱歌状态')}")
print()

# guard 限流自检
s2 = importlib.util.spec_from_file_location(
    "g", "/AstrBot/data/plugins/dsh-reply-guard/main.py")
m2 = importlib.util.module_from_spec(s2)
s2.loader.exec_module(m2)
print("  reply-guard 运行参数:")
print(f"    RATE={m2.RATE_MAX}/{m2.RATE_WINDOW}s  STALE_LAG={m2.STALE_LAG}")
print(f"    SKEW 启用={m2.STALE_ENABLED}  主人豁免={m2.OWNER_BYPASS_RATE}")
