import ast
import sys

P = "/AstrBot/data/plugins/dsh-sing/main.py"
ast.parse(open(P, encoding="utf-8").read())
print("  语法 OK")

sys.path.insert(0, "/AstrBot")
import importlib.util

spec = importlib.util.spec_from_file_location("s", P)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print("  ✅ 导入成功")
print("  插件类:", [n for n in dir(m) if n.endswith("Plugin")])
print("  _SHOWN 类型:", type(m._SHOWN).__name__)
print("  _umo 可调用:", callable(m._umo))

print()
print("  「选 N」/裸数字 正则匹配:")
PAT = r"^\s*(?:@\S+\s*)?(?:(?:选|听|要|来)\s*)?(\d{1,3})\s*$"
for t in ["选 1", "选1", "听 2", "来 3", "@小鲸鱼 选 1", "1", "42", "选 999", "今天好热", "1000"]:
    mm = m.re.match(PAT, t)
    ex = bool(m.re.search(r"(?:选|听|要|来)\s*\d", t))
    print(f"    {t!r:16} → 序号={mm.group(1) if mm else None:>4}  显式={ex}")
