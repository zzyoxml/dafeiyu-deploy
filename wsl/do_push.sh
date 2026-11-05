#!/bin/bash
# 权限改好后运行：bash /root/do_push.sh
set -u
cd /opt/dafeiyu
TOK=$(tr -d '\n\r ' < /root/.gh_token)
GIT_TERMINAL_PROMPT=0 git -c credential.helper= \
  push "https://zzyoxml:${TOK}@github.com/zzyoxml/dafeiyu-deploy.git" \
  main:main
echo "退出码: $?"
