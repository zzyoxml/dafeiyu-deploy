#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 本地仓库现状（等你的空仓库建好后即可推送）==="
echo ""
echo "  分支:    $(git branch --show-current)"
echo "  提交:    $(git log --oneline -1)"
echo "  文件数:  $(git ls-tree -r HEAD --name-only | wc -l)"
echo "  仓库体积: $(du -sh .git | cut -f1)"
echo ""
echo "  remotes:"
git remote -v | sed 's/^/    /'

echo ""
echo "=== 上游已拉取，能否对比 ==="
if git rev-parse upstream/main >/dev/null 2>&1; then
  echo "  ✅ upstream/main 已就绪"
  echo "  上游最新: $(git log upstream/main -1 --format='%h %ad %s' --date=short | cut -c1-70)"
  echo ""
  echo "  本地 vs 上游 文件差异:"
  git diff --stat HEAD upstream/main 2>/dev/null | tail -3 | sed 's/^/    /'
else
  echo "  ⚠ 上游未拉取"
fi

echo ""
echo "=== 待推送内容预览 ==="
echo "  顶层:"
git ls-tree HEAD --name-only | sed 's/^/    /'
echo ""
echo "  插件数: $(git ls-tree -r HEAD --name-only | grep -c 'plugins/dsh-')"
echo "  探针脚本: $(git ls-tree -r HEAD --name-only | grep -c '^probe/')"
