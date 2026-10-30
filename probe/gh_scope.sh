#!/bin/bash
set -u
TOK=$(tr -d '\n\r ' < /root/.gh_token)

echo "=== 1. token 能看到哪些仓库（含私有，判断是否 all-repos）==="
curl -s -m 20 "https://api.github.com/user/repos?per_page=100&affiliation=owner" \
  -H "Authorization: Bearer $TOK" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
if isinstance(d,list):
    print(f'  可见 {len(d)} 个:')
    for r in d: print(f'    {r[\"full_name\"]:35} private={r[\"private\"]}')
else: print('  ❌',d.get('message'))
"

echo ""
echo "=== 2. 查 token 的 fine-grained 元信息（部分可通过 header 得到）==="
curl -s -m 20 -D /tmp/hh.txt -o /dev/null \
  "https://api.github.com/user" -H "Authorization: Bearer $TOK"
grep -iE "x-accepted|x-oauth|x-github" /tmp/hh.txt | head -5 | sed 's/^/  /'

echo ""
echo "=== 3. 判断：新建仓库能否被这个 token 访问 ==="
echo "  fine-grained token 若为 'Only select repositories'，"
echo "  新建的仓库不在选择列表里 → 推送会 403。"
echo "  若为 'All repositories'，新建仓库自动包含 → 可推送。"
echo ""
echo "  上面第 1 步列出了当前可见仓库。若你 GitHub 上有私有仓库但没列出来，"
echo "  说明是 'Only select repositories'，需要改成 All repositories。"
