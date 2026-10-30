#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. robot.env.template 是否含密钥 ==="
if [ -f robot.env.template ]; then
  grep -cE "KEY=.+|TOKEN=.+" robot.env.template 2>/dev/null | xargs -I{} echo "  含值变量: {} 行"
  grep -E "^(DSH_IMG_API_KEY|DSH_IMAGEGEN_KEY|DSH_WEB_SEARCH_KEY)=" robot.env.template 2>/dev/null | sed 's/=.*/=<有值>/' | sed 's/^/    /'
fi

echo ""
echo "=== 2. 清理暂存区，重加忽略规则 ==="
git rm -r --cached . -q 2>/dev/null
cat >> .gitignore <<'EOF'

# 配置备份（含旧密钥，绝不能进仓库）
docker-compose.yml.bak*
robot.env.template
robot.env*
*.mjs.patched
EOF
echo "  已补充忽略规则"

echo ""
echo "=== 3. 重新计算待提交内容 ==="
git add -A 2>/dev/null
echo "  文件数: $(git ls-files | wc -l)"
echo "  体积:   $(git ls-files -z | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1)"

echo ""
echo "=== 4. 按顶层目录分布 ==="
git ls-files | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -8

echo ""
echo "=== 5. 最终密钥检查：扫描所有待提交文件的敏感模式 ==="
HIT=0
while read f; do
  [ -f "$f" ] || continue
  case "$f" in
    *.py|*.yml|*.yaml|*.sh|*.md|*.json|*.txt|*.example|*template*) ;;
    *) continue ;;
  esac
  # 智谱 key 形式：32位hex.16位字母数字
  if grep -qE "github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|[0-9a-f]{32}\.[A-Za-z0-9]{14,}" "$f" 2>/dev/null; then
    echo "  ⚠ $f"
    grep -oE "github_pat_[A-Za-z0-9_]{10}|sk-[A-Za-z0-9]{10}|[0-9a-f]{32}\.[A-Za-z0-9]{10}" "$f" | head -3 | sed 's/^/      /'
    HIT=1
  fi
done < <(git ls-files)
[ "$HIT" = "0" ] && echo "  ✅ 未发现明文密钥"

echo ""
echo "=== 6. 大文件检查（>1MB）==="
git ls-files -z | xargs -0 du -h 2>/dev/null | awk '$1 ~ /M$/ && $1+0 >= 1 {print "  "$0}' | head -10
echo "  （以上如有，确认是否该提交）"
