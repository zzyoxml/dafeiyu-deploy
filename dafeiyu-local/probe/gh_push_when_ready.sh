#!/bin/bash
set -u
cd /opt/dafeiyu
TOK=$(tr -d '\n\r ' < /root/.gh_token)

echo "=== 检测 zzyoxml/dafeiyu-deploy 是否已存在 ==="
R=$(curl -s -m 20 -H "Authorization: Bearer $TOK" \
     -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/zzyoxml/dafeiyu-deploy")

if echo "$R" | grep -q '"full_name"'; then
  echo "  ✅ 仓库已存在！"
  echo "$R" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'     名称:   {d[\"full_name\"]}')
print(f'     私有:   {d[\"private\"]}')
print(f'     空仓:   {d[\"size\"]}KB')
print(f'     权限:   {d.get(\"permissions\",{})}')
"
  echo ""
  echo "=== 尝试推送 ==="
  git -c "credential.helper=" \
      push "https://zzyoxml:${TOK}@github.com/zzyoxml/dafeiyu-deploy.git" \
      main:main 2>&1 | tail -8
else
  echo "  ❌ 尚未创建"
  echo "$R" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('     原因:', d.get('message'))
"
  echo ""
  echo "  请到 https://github.com/new 创建："
  echo "     Repository name: dafeiyu-deploy"
  echo "     Visibility:       Private"
  echo "     不要勾选 Add a README / .gitignore / license（保持空仓）"
  echo ""
  echo "  建好后告诉我，我会："
  echo "    1. 推送 main"
  echo "    2. 配置 upstream 跟踪"
  echo "    3. 验证推送内容不含密钥"
fi
