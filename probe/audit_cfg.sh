#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. cmd_config.json 及其备份是否含密钥（这份配置管全部插件）==="
for f in data/astrbot/cmd_config.json data/astrbot/cmd_config.json.bak-*; do
  [ -f "$f" ] || continue
  N=$(grep -oE '"(key|token|secret|api_key|cookie|password)"\s*:\s*"[^"]{8,}"' "$f" 2>/dev/null | wc -l)
  echo "  $(basename $f): 可疑字段 $N 处"
done

echo ""
echo "=== 2. cmd_config.json 里到底有哪些插件配置（看是否含真 key）==="
if [ -f data/astrbot/cmd_config.json ]; then
  python3 - <<'PYEOF'
import json, re
try:
    d = json.load(open('/opt/dafeiyu/data/astrbot/cmd_config.json', encoding='utf-8'))
except Exception as e:
    print("  解析失败:", e); raise SystemExit
cnt = 0
def walk(o, p=""):
    global cnt
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(v, str) and any(s in k.lower() for s in
                    ("key","token","secret","cookie","password","credential")):
                if v.strip() and not v.startswith("<") and len(v) > 6:
                    print(f"    ⚠ {p}{k} = {v[:8]}…")
                    cnt += 1
            else:
                walk(v, f"{p}{k}.")
    elif isinstance(o, list):
        for i, x in enumerate(o[:50]):
            walk(x, f"{p}[{i}].")
walk(d)
print(f"  合计可疑字段: {cnt}")
PYEOF
fi

echo ""
echo "=== 3. astrbot_plugin_anysearch 是什么（第三方插件）==="
ls data/astrbot/plugins/astrbot_plugin_anysearch/ 2>/dev/null | head -10
echo "  含配置文件:"
find data/astrbot/plugins/astrbot_plugin_anysearch -name "*.json" -o -name "*.yaml" 2>/dev/null | head -5 | sed 's/^/    /'

echo ""
echo "=== 4. 该第三方插件是否有硬编码 key ==="
grep -rlE "sk-[A-Za-z0-9]{15,}|[0-9a-f]{32}\.[A-Za-z0-9]{12,}" \
  data/astrbot/plugins/astrbot_plugin_anysearch/ 2>/dev/null | head -5 || echo "  无"

echo ""
echo "=== 5. 统计待清理的 .bak 数量 ==="
echo "  .bak 文件: $(git ls-files 2>/dev/null | grep -cE '\.bak') 个"
echo "  __pycache__ 目录: $(find data/astrbot/plugins -type d -name __pycache__ 2>/dev/null | wc -l) 个"
