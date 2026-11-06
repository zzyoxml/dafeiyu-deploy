#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 覆盖 .gitignore ==="
[ -f .gitignore ] && cp .gitignore .gitignore.bak-$(date +%H%M%S)
echo "  已备份旧版"

echo ""
echo "=== 2. 清空暂存区 ==="
git rm -r --cached . -q 2>/dev/null || true
rm -rf .git/index 2>/dev/null
echo "  已清空"

echo ""
echo "=== 3. 重新暂存 ==="
git add -A 2>/dev/null
echo "  文件数: $(git ls-files | wc -l)"
echo "  体积:   $(git ls-files -z | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1)"

echo ""
echo "=== 4. 验证敏感文件全部被排除 ==="
for f in robot.env robot.env.template onebot11.json \
         data/astrbot/cmd_config.json \
         data/astrbot/data_v4.db \
         data/astrbot/sing/model/liuying.pth \
         data/astrbot/sing/venv/bin/python \
         data/astrbot/plugins/dsh-voice/main.py.bak-edge \
         docker-compose.yml.bak-noauth-20261028-1629 \
         data/astrbot/sing/rvc/models/embedders/contentvec/pytorch_model.bin; do
  if [ -e "$f" ]; then
    R=$(git check-ignore "$f" 2>/dev/null)
    [ -n "$R" ] && echo "  ✅ 已排除: $f" || echo "  ❌ 仍会被提交: $f"
  fi
done

echo ""
echo "=== 5. 提交清单按目录 ==="
git ls-files | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -10

echo ""
echo "=== 6. 全部待提交文件里的最大 10 个 ==="
git ls-files -z | xargs -0 du -h 2>/dev/null | sort -rh | head -10 | sed 's/^/  /'

echo ""
echo "=== 7. 兜底：再次全量扫密钥 ==="
HIT=0
for f in $(git ls-files 2>/dev/null); do
  [ -f "$f" ] || continue
  case "$f" in *.py|*.yml|*.yaml|*.sh|*.md|*.json|*.txt) ;; *) continue ;; esac
  O=$(grep -nE "(sk-[A-Za-z0-9]{18,}|github_pat_[A-Za-z0-9_]{18,}|[0-9a-f]{32}\.[A-Za-z0-9]{14,}|Bearer\ [A-Za-z0-9]{18,})" "$f" 2>/dev/null | head -1)
  [ -n "$O" ] && { echo "  ⚠ $f: $(echo "$O" | cut -c1-70)"; HIT=$((HIT+1)); }
done
echo "  命中: $HIT 个文件"
