#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 备份目录跑到仓库里了，移出去 ==="
for d in .git-old-*; do
  [ -d "$d" ] || continue
  echo "  移出: $d"
  mv "$d" "/root/$d"
done

echo ""
echo "=== 2. 补忽略：备份目录 + 嵌套 git ==="
cat >> .gitignore <<'EOF'

# git 历史备份（不能进仓库）
.git-old-*/
.git.bak-*/

# 第三方插件的嵌套 git（用 .gitignore 忽略而不是 submodule）
data/astrbot/plugins/*/.git/
EOF

echo ""
echo "=== 3. 彻底重来 ==="
rm -rf .git
git init -b main -q
git config user.name "zzyoxml"
git config user.email "zzyoxml@users.noreply.github.com"
git config core.quotepath false
git remote add origin "https://github.com/zzyoxml/dafeiyu-deploy.git"
git remote add upstream "https://github.com/nanbengxian-cyber/dafeiyu-qq-bot.git"

echo "=== 4. 嵌套 git 仓库：先移走再删 ==="
NESTED=data/astrbot/plugins/astrbot_plugin_anysearch/.git
if [ -d "$NESTED" ]; then
  mv "$NESTED" /root/anysearch-git-backup
  echo "  已移走 anysearch 的 .git（内容仍在，只是不要嵌套仓库）"
fi

echo ""
echo "=== 5. 暂存 ==="
git add -A 2>&1 | grep -v "^hint:" | head -5
echo "  文件数: $(git ls-files | wc -l)"
echo "  体积:   $(git ls-files -z | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1)"

echo ""
echo "=== 6. 验证 ==="
echo "  ── 敏感文件 ──"
for f in robot.env onebot11.json data/astrbot/cmd_config.json \
         patches/napcat.mjs.patched data/astrbot/plugins/dsh-slang/slang.json \
         data/astrbot/dsh_emotion_state.json data/astrbot/data_v4.db \
         data/astrbot/sing/model/liuying.pth data/astrbot/sing/venv/bin/python; do
  [ -e "$f" ] || continue
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 \
    && echo "    ❌ $f" || echo "    ✅ $f"
done

echo ""
echo "  ── 目录分布 ──"
git ls-files | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -8 | sed 's/^/    /'
