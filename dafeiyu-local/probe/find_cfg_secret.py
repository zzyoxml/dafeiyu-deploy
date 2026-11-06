import json
import re

P = "/opt/dafeiyu/data/astrbot/cmd_config.json"
raw = open(P, encoding="utf-8-sig").read()
d = json.loads(raw)


def walk(o, p=""):
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(v, str) and any(
                s in k.lower() for s in
                ("key", "token", "secret", "cookie", "password", "credential")
            ):
                if v.strip() and len(v) > 6:
                    print(f"  ⚠ {p}{k}")
                    print(f"      长度={len(v)}  前6={v[:6]}…  后4=…{v[-4:]}")
            else:
                walk(v, f"{p}{k}.")
    elif isinstance(o, list):
        for i, x in enumerate(o):
            walk(x, f"{p}[{i}].")


print("=== cmd_config.json 可疑字段定位 ===")
walk(d)

# 同时扫描所有字符串值里"像 key"的
print()
print("=== 所有像密钥的字符串值（不看字段名）===")
pat = re.compile(r"(sk-[A-Za-z0-9]{15,}|[0-9a-f]{32}\.[A-Za-z0-9]{12,}|"
                 r"github_pat_[A-Za-z0-9_]{15,}|[A-Za-z0-9_-]{40,})")
hits = []


def scan(o, p=""):
    if isinstance(o, dict):
        for k, v in o.items():
            scan(v, f"{p}{k}.")
    elif isinstance(o, list):
        for i, x in enumerate(o):
            scan(x, f"{p}[{i}].")
    elif isinstance(o, str) and pat.search(o):
        hits.append((p, o[:20]))


scan(d)
for p, v in hits[:10]:
    print(f"  {p} = {v}…")
print(f"  合计 {len(hits)} 处")
