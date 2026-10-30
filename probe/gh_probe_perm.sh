#!/bin/bash
set -u
TOK=$(tr -d '\n\r ' < /root/.gh_token)

echo "=== 1. token 类型判断 ==="
case "$TOK" in
  github_pat_*) echo "  fine-grained PAT（权限需逐项勾选）" ;;
  ghp_*)        echo "  classic PAT（按 scope 授权）" ;;
  *)            echo "  未知格式" ;;
esac

echo ""
echo "=== 2. 探测能否建仓（试一个临时名字）==="
R=$(curl -s -m 20 -X POST "https://api.github.com/user/repos" \
  -H "Authorization: Bearer $TOK" \
  -H "Accept: application/vnd.github+json" \
  -d '{"name":"dafeiyu-probe-test","private":true,"auto_init":false}')
echo "$R" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('  结果:', d.get('message') or d.get('full_name','?'))
if 'errors' in d:
    for e in d['errors']:
        print('     code:', e.get('code'), '| field:', e.get('field'), '|', e.get('message',''))
"
# 若真建成则删掉
if echo "$R" | grep -q '"full_name"'; then
  echo "  ⚠ 竟然建成了，立即删除"
  curl -s -m 20 -X DELETE "https://api.github.com/repos/zzyoxml/dafeiyu-probe-test" \
    -H "Authorization: Bearer $TOK" >/dev/null
fi

echo ""
echo "=== 3. 测试对已存在仓库的写权限（md3Music）==="
curl -s -m 20 "https://api.github.com/repos/zzyoxml/md3Music" \
  -H "Authorization: Bearer $TOK" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
p=d.get('permissions',{})
print(f'  md3Music 权限: admin={p.get(\"admin\")} push={p.get(\"push\")} pull={p.get(\"pull\")}')
"

echo ""
echo "=== 4. 结论 ==="
echo "  读公开仓库：✅ 可以（upstream fetch 已成功）"
echo "  建新仓库：  需要 Account permissions → Repository creation = write"
echo "  推送到新仓库：需要该仓库 Contents = write（仓库得先存在）"
