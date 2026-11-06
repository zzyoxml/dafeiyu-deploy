#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 初始化仓库 ==="
if [ -d .git ]; then
  echo "  已存在 .git，跳过"
else
  git init -b main 2>&1 | tail -2
fi

echo ""
echo "=== 2. 配置（本地仓库级，不动全局）==="
git config user.name "大肥鱼" 2>/dev/null || true
git config user.email "dafeiyu@local" 2>/dev/null || true
git config core.quotepath false
echo "  user: $(git config user.name) <$(git config user.email)>"

echo ""
echo "=== 3. 检查忽略效果：将要提交什么 ==="
git add -A --dry-run 2>/dev/null | wc -l | xargs -I{} echo "  待添加文件数: {}"
echo ""
echo "  按目录统计:"
git add -A --dry-run 2>/dev/null | sed "s/^add '//;s/'$//" | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -10

echo ""
echo "=== 4. 关键：确认排除了大文件 ==="
for f in data/astrbot/sing/model/liuying.pth data/astrbot/sing/venv/bin/python \
         data/astrbot/temp robot.env data/astrbot/data_v4.db \
         data/astrbot/sing/rvc/models/embedders/contentvec/pytorch_model.bin; do
  R=$(git check-ignore -v "$f" 2>/dev/null | head -1)
  if [ -n "$R" ]; then
    echo "  ✅ 已忽略: $f"
  else
    echo "  ⚠ 未忽略: $f"
  fi
done

echo ""
echo "=== 5. 预计提交体积 ==="
git add -A 2>/dev/null
git ls-files -z 2>/dev/null | xargs -0 du -ch 2>/dev/null | tail -1
echo "  文件数: $(git ls-files 2>/dev/null | wc -l)"
