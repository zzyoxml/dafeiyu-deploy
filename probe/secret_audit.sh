#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. onebot11.json 是否含 token ==="
if [ -f onebot11.json ]; then
  python3 -c "
import json
d=json.load(open('/opt/dafeiyu/onebot11.json'))
def walk(o,p=''):
    if isinstance(o,dict):
        for k,v in o.items():
            if any(s in k.lower() for s in ('token','key','secret','password')) and v:
                print(f'  ⚠ {p}{k} = {str(v)[:10]}… (有值)')
            else:
                walk(v,f'{p}{k}.')
walk(d)
print('  （无输出即无敏感字段）')
"
fi

echo ""
echo "=== 2. docker-compose.yml 是否含明文密钥 ==="
grep -nE "TOKEN|KEY|SECRET|PASSWORD" docker-compose.yml 2>/dev/null | grep -vE "^\s*#" | sed 's/\(.\{70\}\).*/\1…/' | sed 's/^/  /' || echo "  无"

echo ""
echo "=== 3. 待提交文件里所有 .bak 备份 ==="
git ls-files 2>/dev/null | grep -E "\.bak|\.orig|~$" | head -10 || echo "  无"

echo ""
echo "=== 4. plugins 目录里的非源码文件 ==="
git ls-files data/astrbot/plugins 2>/dev/null | grep -vE "\.(py|yaml|yml|md|txt|json|toml|cfg|ini|example)$" | head -15 || echo "  只有源码与配置"

echo ""
echo "=== 5. 全量敏感模式扫描（含中文注释里的示例key）==="
echo "  模式: sk-xxx / github_pat_xxx / 32hex.16alnum / Bearer xxx / 纯32位hex"
HIT=0
for f in $(git ls-files 2>/dev/null); do
  [ -f "$f" ] || continue
  OUT=$(grep -nE "(sk-[A-Za-z0-9]{18,}|github_pat_[A-Za-z0-9_]{18,}|[0-9a-f]{32}\.[A-Za-z0-9]{14,}|Bearer\ [A-Za-z0-9]{18,})" "$f" 2>/dev/null | head -2)
  if [ -n "$OUT" ]; then
    echo "  ⚠ $f"
    echo "$OUT" | sed 's/^/      /' | cut -c1-100
    HIT=$((HIT+1))
  fi
done
echo "  命中文件数: $HIT"

echo ""
echo "=== 6. 上面结果里 why 文件是什么（举例看内容）==="
echo "  （不打印敏感值，只列文件名）"
