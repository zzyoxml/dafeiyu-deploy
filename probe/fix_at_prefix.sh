#!/bin/bash
set -u
echo "=== 1. 部署 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
echo "  已复制"

echo ""
echo "=== 2. 正则匹配测试（关键：验证 @前缀 能命中）==="
cat > /tmp/test_regex.py <<'PYEOF'
import re

PATTERNS = {
    "唱歌状态": r"^\s*(?:@\S+\s*)?/?唱歌状态\s*$",
    "搜歌":     r"^\s*(?:@\S+\s*)?/?搜歌(?:\s+|$)",
    "原唱":     r"^\s*(?:@\S+\s*)?/?原唱(?:\s+|$)",
    "唱歌":     r"^\s*(?:@\S+\s*)?/?唱歌(?:\s+|$)",
    "翻唱":     r"^\s*(?:@\S+\s*)?/?翻唱(?:\s+|$)",
}

CASES = [
    "@小鲸鱼 /唱歌 全球变冷",
    "@小鲸鱼 /唱歌 十年",
    "/唱歌 夜曲",
    "唱歌 夜曲",
    "@小鲸鱼 /唱歌状态",
    "/唱歌状态",
    "@小鲸鱼 /搜歌 稻香",
    "@小鲸鱼 /原唱 十年",
    "今天天气不错",          # 不应命中
    "唱歌真不会",            # 旧实现会命中吗？不应
]

for text in CASES:
    hits = [k for k, p in PATTERNS.items() if re.search(p, text)]
    print(f"  {text!r:40} → {hits if hits else '（不匹配）'}")

print()
print("  歌名提取验证:")
for text in ("@小鲸鱼 /唱歌 全球变冷", "/唱歌 夜曲", "@小鲸鱼 唱歌 十年"):
    s = re.sub(r"^\s*@\S+\s*", "", text)
    s = re.sub(r"^/?(?:唱歌|翻唱|原唱)\s*", "", s).strip()
    print(f"    {text!r:32} → 歌名={s!r}")
PYEOF
docker cp /tmp/test_regex.py astrbot:/tmp/test_regex.py
docker exec astrbot python3 /tmp/test_regex.py 2>&1

echo ""
echo "=== 3. 语法检查 ==="
docker exec astrbot python3 /tmp/check_sing.py 2>&1 | grep -E "语法|导入|插件类"

echo ""
echo "=== 4. 热重载 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 200
echo ""
