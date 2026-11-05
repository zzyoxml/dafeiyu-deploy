#!/bin/bash
set -u
cd /opt/dafeiyu
TOK=$(tr -d '\n\r ' < /root/.gh_token)

echo "尝试 HTTPS（token）..."
if GIT_TERMINAL_PROMPT=0 timeout 90 git -c credential.helper= \
   push "https://zzyoxml:${TOK}@github.com/zzyoxml/dafeiyu-deploy.git" \
   main:main 2>&1 | tail -3; then
  echo "HTTPS 完成"
  exit 0
fi

echo "HTTPS 失败，尝试 SSH..."
git remote set-url origin git@github.com:zzyoxml/dafeiyu-deploy.git
timeout 90 git push origin main:main 2>&1 | tail -3
