#!/bin/bash
set -u
cd /opt/dafeiyu
TOK=$(tr -d '\n\r ' < /root/.gh_token)

echo "=== 1. 创建私有仓库 zzyoxml/dafeiyu-deploy ==="
RESP=$(curl -s -m 30 -X POST "https://api.github.com/user/repos" \
  -H "Authorization: Bearer $TOK" \
  -H "Accept: application/vnd.github+json" \
  -d '{
    "name": "dafeiyu-deploy",
    "description": "大肥鱼 QQ 机器人的本地部署与二次开发。上游 nanbengxian-cyber/dafeiyu-qq-bot。自建 dsh-sing 点歌翻唱(带缓存)、dsh-voice-liuying 流萤音色语音、dsh-reply-guard 限流。",
    "private": true,
    "has_issues": true,
    "has_wiki": false,
    "auto_init": false
  }')
echo "$RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if 'full_name' in d:
    print(f'  ✅ 已创建: {d[\"full_name\"]}')
    print(f'     private: {d[\"private\"]}')
    print(f'     clone:   {d[\"clone_url\"]}')
    print(f'     ssh:     {d[\"ssh_url\"]}')
elif 'errors' in d:
    print('  ❌ 创建失败:')
    for e in d['errors']: print('     ', e)
else:
    print('  ❌', d.get('message'))
"

echo ""
echo "=== 2. 配置 remote ==="
git remote remove origin 2>/dev/null || true
git remote remove upstream 2>/dev/null || true
git remote add origin "https://github.com/zzyoxml/dafeiyu-deploy.git"
git remote add upstream "https://github.com/nanbengxian-cyber/dafeiyu-qq-bot.git"
echo "  remote 列表:"
git remote -v | sed 's/^/    /'

echo ""
echo "=== 3. 推送 main（用 token 认证，不写进 .git/config）==="
git -c "credential.helper=" \
    push "https://zzyoxml:${TOK}@github.com/zzyoxml/dafeiyu-deploy.git" main 2>&1 | tail -6

echo ""
echo "=== 4. 设置上游跟踪分支 ==="
git fetch upstream main --depth=1 2>&1 | tail -3 || echo "  拉上游失败（不影响）"
