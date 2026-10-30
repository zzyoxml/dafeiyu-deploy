#!/bin/bash
set -u
# ── 0. 安全存 token：写在仓库外的 /root/.gh_token，600 权限 ──
[ -f /root/.gh_token ] || { echo "缺少 token 文件"; exit 1; }
chmod 600 /root/.gh_token
TOK=$(tr -d '\n\r ' < /root/.gh_token)
echo "=== 0. token 已存 /root/.gh_token（600，不在仓库内）==="
echo "  长度 ${#TOK}，前缀 ${TOK:0:11}..."

echo ""
echo "=== 1. 验证 token + 拿账号 ==="
curl -s -m 15 -H "Authorization: Bearer $TOK" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/user \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
if 'login' in d:
    print(f'  登录名: {d[\"login\"]}')
    print(f'  类型:   {d.get(\"type\")}')
    print(f'  名字:   {d.get(\"name\")}')
else:
    print('  ❌', d.get('message'))
"

echo ""
echo "=== 2. token 权限范围（能否建仓）==="
curl -s -m 15 -H "Authorization: Bearer $TOK" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/user \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
sc = d.get('x-oauth-scopes')
print(f'  scopes 头（classic 才有）: {sc}')
"
curl -s -m 15 -D /tmp/h.txt -o /dev/null -H "Authorization: Bearer $TOK" \
     https://api.github.com/rate_limit
echo "  剩余配额: $(grep -i 'x-ratelimit-remaining' /tmp/h.txt | tr -d '\r' | cut -d' ' -f2)"

echo ""
echo "=== 3. 上游仓库核实 ==="
for r in nanbengxian-cyber/dafeiyu-qq-bot; do
  echo "  ── $r ──"
  curl -s -m 15 -H "Authorization: Bearer $TOK" \
       "https://api.github.com/repos/$r" \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
if 'full_name' in d:
    print(f'    存在，private={d[\"private\"]} fork={d.get(\"fork\")}')
    print(f'    默认分支: {d[\"default_branch\"]}  大小: {d[\"size\"]}KB')
    print(f'    description: {(d.get(\"description\") or \"\")[:60]}')
else:
    print(f'    ❌ {d.get(\"message\")}')
"
done

echo ""
echo "=== 4. 当前账号有哪些仓库（找已有 fork / 目标名）==="
curl -s -m 15 -H "Authorization: Bearer $TOK" \
     "https://api.github.com/user/repos?per_page=100&sort=updated" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
if isinstance(d,list):
    print(f'  共 {len(d)} 个')
    for r in d[:15]:
        print(f'    {r[\"full_name\"]}  private={r[\"private\"]}')
else:
    print('  ❌', d.get('message'))
"
