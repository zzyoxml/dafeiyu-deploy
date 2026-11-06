#!/bin/bash
set -u
echo "=== 1. /opt/dafeiyu 结构（一级）==="
ls -la /opt/dafeiyu/ | head -20

echo ""
echo "=== 2. 各部分体积 ==="
du -sh /opt/dafeiyu/* 2>/dev/null | sort -h | tail -15
echo ""
echo "  总计: $(du -sh /opt/dafeiyu 2>/dev/null | cut -f1)"

echo ""
echo "=== 3. git 是否可用 ==="
git --version 2>&1
echo "  全局配置:"
git config --global --list 2>/dev/null | head -10 || echo "    无全局配置"

echo ""
echo "=== 4. 是否已有 git 仓库 ==="
for d in /opt/dafeiyu /opt/dafeiyu/data/astrbot /opt/dafeiyu/data/astrbot/plugins; do
  if [ -d "$d/.git" ]; then
    echo "  $d 已是 git 仓库"
    git -C "$d" remote -v 2>/dev/null | sed 's/^/    /'
  else
    echo "  $d 不是 git 仓库"
  fi
done

echo ""
echo "=== 5. GitHub 认证 ==="
which gh 2>/dev/null && gh auth status 2>&1 | head -8 || echo "  无 gh CLI"
echo ""
echo "  ssh key:"
ls ~/.ssh/*.pub 2>/dev/null | sed 's/^/    /' || echo "    无"
echo "  git credential:"
ls ~/.git-credentials 2>/dev/null && echo "    有凭据文件" || echo "    无"
