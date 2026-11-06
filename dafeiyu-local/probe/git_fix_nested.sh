#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 嵌套 .git 目录（会导致 submodule 警告）==="
find data/astrbot/plugins -maxdepth 2 -name ".git" -type d 2>/dev/null | sed 's/^/  /'

echo ""
echo "=== 2. knowledge_base 是什么 ==="
ls -la data/astrbot/knowledge_base/ 2>/dev/null | head -5

echo ""
echo "=== 3. repo/plugins 是谁的克隆（有无 .git）==="
ls -d repo/plugins/.git 2>/dev/null && echo "  有 .git" || echo "  无 .git（纯拷贝，安全）"

echo ""
echo "=== 4. 处理：补忽略规则 ==="
cat >> .gitignore <<'EOF'

# 第三方插件的嵌套 git（会触发 submodule 警告）
data/astrbot/plugins/*/.git/
data/astrbot/plugins/*/.github/

# 知识库（运行期生成，含群聊内容）
data/astrbot/knowledge_base/
EOF
echo "  已追加"

echo ""
echo "=== 5. 清空并重新暂存 ==="
rm -rf .git/index
git add -A 2>/dev/null
echo "  文件数: $(git ls-files | wc -l)"
echo "  体积:   $(git ls-files -z | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1)"

echo ""
echo "=== 6. 检查是否还有嵌套 .git 被跟踪 ==="
git ls-files | grep -c "/\.git/" | xargs -I{} echo "  .git 内文件被跟踪: {} 个"
git ls-files | grep "anysearch" | head -8 | sed 's/^/    /'

echo ""
echo "=== 7. 最终目录分布 ==="
git ls-files | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -8
