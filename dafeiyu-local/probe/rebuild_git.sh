#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 现状：历史里有敏感文件吗 ==="
for f in patches/napcat.mjs.patched data/astrbot/plugins/dsh-slang/slang.json \
         data/astrbot/dsh_emotion_state.json robot.env; do
  C=$(git log --all --oneline -- "$f" 2>/dev/null | wc -l)
  echo "  $f: 历史提交 $C 次"
done

echo ""
echo "=== 2. 决定：重建历史（没有 push 过，最干净）==="
echo "  未推送，直接删 .git 重建，一步到位无残留。"

echo ""
echo "=== 3. 备份旧仓库（万一要回滚）==="
if [ -d .git ]; then
  mv .git .git-old-$(date +%H%M%S)
  echo "  旧仓库已备份为 .git-old-*"
fi

echo ""
echo "=== 4. 全新初始化 ==="
git init -b main -q
git config user.name "zzyoxml"
git config user.email "zzyoxml@users.noreply.github.com"
git config core.quotepath false
echo "  ✅ 新仓库，user=$(git config user.name)"

echo ""
echo "=== 5. remote ==="
git remote add origin "https://github.com/zzyoxml/dafeiyu-deploy.git"
git remote add upstream "https://github.com/nanbengxian-cyber/dafeiyu-qq-bot.git"
git remote -v | sed 's/^/  /'

echo ""
echo "=== 6. 加入所有（.gitignore 已就位）==="
git add -A
echo "  文件数: $(git ls-files | wc -l)"
echo "  体积:   $(git ls-files -z | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1)"

echo ""
echo "=== 7. 验证敏感文件不在暂存区 ==="
for f in robot.env onebot11.json data/astrbot/cmd_config.json \
         patches/napcat.mjs.patched data/astrbot/plugins/dsh-slang/slang.json \
         data/astrbot/dsh_emotion_state.json data/astrbot/data_v4.db \
         data/astrbot/sing/model/liuying.pth; do
  [ -e "$f" ] || continue
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo "  ❌ 仍被跟踪: $f"
  else
    echo "  ✅ 已排除: $f"
  fi
done
