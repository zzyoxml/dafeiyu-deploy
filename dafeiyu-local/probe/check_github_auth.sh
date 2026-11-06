#!/bin/bash
set -u
echo "=== 1. 找现成的 GitHub 凭据 ==="
echo "  环境变量:"
env | grep -iE "GITHUB|GH_TOKEN|GIT_" | sed 's/=.*/=<已设置>/' | sed 's/^/    /' || echo "    无"
echo ""
echo "  文件:"
for f in ~/.git-credentials ~/.config/gh/hosts.yml /root/.git-credentials; do
  [ -f "$f" ] && echo "    存在: $f" || echo "    无: $f"
done

echo ""
echo "=== 2. 原项目来源（判断 GitHub 账号）==="
cat /opt/dafeiyu/repo/plugins/.git/config 2>/dev/null | head -10 || echo "  repo/plugins 无 .git"
echo ""
echo "  部署来源记录:"
grep -rn "github.com" /opt/dafeiyu/_setup.sh 2>/dev/null | head -5

echo ""
echo "=== 3. 测试 GitHub 连通性 ==="
curl -s -m 10 -o /dev/null -w "  github.com → HTTP %{http_code}\n" https://github.com 2>&1
curl -s -m 10 -o /dev/null -w "  api.github.com → HTTP %{http_code}\n" https://api.github.com 2>&1

echo ""
echo "=== 4. 用户之前提到的仓库 ==="
echo "  nanbengxian-cyber/dafeiyu-qq-bot（原始来源）"
curl -s -m 10 "https://api.github.com/repos/nanbengxian-cyber/dafeiyu-qq-bot" 2>&1 | grep -E '"full_name"|"private"|"message"' | head -3
