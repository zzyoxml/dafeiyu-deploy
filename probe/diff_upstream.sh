#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. repo/plugins 与上游一致性 ==="
if [ -d repo/plugins/.git ]; then
  echo "  是独立 git 仓库:"
  git -C repo/plugins remote -v 2>/dev/null | sed 's/^/    /'
  echo "    分支: $(git -C repo/plugins branch --show-current 2>/dev/null)"
  echo "    最新: $(git -C repo/plugins log -1 --format='%h %ad %s' --date=short 2>/dev/null | cut -c1-70)"
  echo "    本地改动:"
  git -C repo/plugins status --porcelain 2>/dev/null | head -10 | sed 's/^/      /'
  echo "    改动文件数: $(git -C repo/plugins status --porcelain 2>/dev/null | wc -l)"
else
  echo "  不是 git 仓库，只是拷贝"
fi

echo ""
echo "=== 2. 本地部署插件 vs 上游插件（找出自建的）==="
UPSTREAM="/opt/dafeiyu/repo/plugins"
DEPLOYED="/opt/dafeiyu/data/astrbot/plugins"
echo "  上游有: $(ls -d $UPSTREAM/dsh-* 2>/dev/null | wc -l) 个"
echo "  部署有: $(ls -d $DEPLOYED/dsh-* 2>/dev/null | wc -l) 个"
echo ""
echo "  ── 仅部署层才有的（我自建 / 改过名的）──"
for d in $(ls -d $DEPLOYED/dsh-* 2>/dev/null); do
  n=$(basename "$d")
  [ ! -d "$UPSTREAM/$n" ] && echo "      $n"
done

echo ""
echo "=== 3. 上游 plugin 与部署 plugin 内容是否一致（抽查 5 个）==="
for n in dsh-voice dsh-emotion dsh-proactive dsh-mention dsh-guard; do
  if [ -d "$UPSTREAM/$n" ] && [ -d "$DEPLOYED/$n" ]; then
    D=$(diff -rq "$UPSTREAM/$n" "$DEPLOYED/$n" 2>/dev/null | grep -v __pycache__ | wc -l)
    if [ "$D" = "0" ]; then
      echo "  ✅ $n 一致"
    else
      echo "  ⚠ $n 有 $D 处差异"
      diff -rq "$UPSTREAM/$n" "$DEPLOYED/$n" 2>/dev/null | grep -v __pycache__ | head -2 | sed 's/^/       /'
    fi
  fi
done

echo ""
echo "=== 4. 敏感关键字扫描：所有待提交 .py 文件 ==="
HIT=0
for f in $(cd /opt/dafeiyu && git ls-files 2>/dev/null | grep -E '\.py$'); do
  if grep -qE "sk-[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|[0-9a-f]{32}\.[A-Za-z0-9]{14,}|Bearer [A-Za-z0-9]{20,}" "/opt/dafeiyu/$f" 2>/dev/null; then
    echo "  ⚠ $f"
    HIT=1
  fi
done
[ "$HIT" = "0" ] && echo "  ✅ 未发现硬编码密钥"
