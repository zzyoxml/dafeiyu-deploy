#!/bin/bash
set -u
TOK=$(tr -d '\n\r ' < /root/.gh_token)
GH="curl -s -m 20 -H Authorization:Bearer\ $TOK -H Accept:application/vnd.github+json"

echo "=== 1. 上游仓库顶层结构 ==="
curl -s -m 20 -H "Authorization: Bearer $TOK" \
  "https://api.github.com/repos/nanbengxian-cyber/dafeiyu-qq-bot/contents/" \
 | python3 -c "
import json,sys
d=json.load(sys.stdin)
if isinstance(d,list):
    for x in d:
        print(f'  {x[\"type\"]:5} {x[\"name\"]}')
else: print('  ❌',d.get('message'))
"

echo ""
echo "=== 2. 上游的 plugins 目录（前 20 个）==="
curl -s -m 20 -H "Authorization: Bearer $TOK" \
  "https://api.github.com/repos/nanbengxian-cyber/dafeiyu-qq-bot/contents/plugins" \
 | python3 -c "
import json,sys
d=json.load(sys.stdin)
if isinstance(d,list):
    print(f'  共 {len(d)} 项')
    for x in d[:20]: print(f'    {x[\"name\"]}')
else: print('  ❌',d.get('message'))
"

echo ""
echo "=== 3. 本地 repo/plugins 内容 ==="
ls /opt/dafeiyu/repo/plugins/ 2>/dev/null | head -20

echo ""
echo "=== 4. 上游 README 开头（了解定位）==="
curl -s -m 20 -H "Authorization: Bearer $TOK" \
  "https://raw.githubusercontent.com/nanbengxian-cyber/dafeiyu-qq-bot/main/README.md" \
  | head -20

echo ""
echo "=== 5. 上游最新 commit ==="
curl -s -m 20 -H "Authorization: Bearer $TOK" \
  "https://api.github.com/repos/nanbengxian-cyber/dafeiyu-qq-bot/commits?per_page=3" \
 | python3 -c "
import json,sys
d=json.load(sys.stdin)
if isinstance(d,list):
    for c in d:
        print(f'  {c[\"sha\"][:8]} {c[\"commit\"][\"author\"][\"date\"][:10]} {c[\"commit\"][\"message\"].splitlines()[0][:60]}')
else: print('  ❌',d.get('message'))
"
