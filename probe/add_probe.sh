#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. /opt/dafeiyu 下有没有 probe ==="
ls -d probe 2>/dev/null && echo "  有" || echo "  无（README 需要改）"

echo ""
echo "=== 2. 实际顶层目录 ==="
git ls-tree HEAD --name-only | sed 's/^/  /'

echo ""
echo "=== 3. 推进 probe（从 Windows 侧复制）==="
SRC=<PROBE_DIR>
if [ -d "$SRC" ]; then
  mkdir -p probe
  # 只复制 .sh / .py，跳过临时产物
  find "$SRC" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.py" \) \
       ! -name "_tmp*" ! -name "*.result" -exec cp {} probe/ \;
  echo "  已复制 $(ls probe/ | wc -l) 个脚本"
  echo "  体积: $(du -sh probe | cut -f1)"
else
  echo "  ❌ 源目录不存在: $SRC"
fi

echo ""
echo "=== 4. 修正 README 里 probe 的描述 ==="
python3 - <<'PYEOF'
import re
p = "/opt/dafeiyu/README.md"
s = open(p, encoding="utf-8").read()
s = s.replace(
    "probe/                   部署与验证脚本，含每个 bug 的复现/验证手段",
    "probe/                   部署与验证脚本，含每个 bug 的复现/验证手段\n"
    "                         （脚本在 Windows 侧生成后推入，用于 WSL2 部署排障）"
)
open(p, "w", encoding="utf-8").write(s)
print("  已更新 README")
PYEOF

echo ""
echo "=== 5. 暂存并提交 ==="
git add -A
echo "  新增文件:"
git diff --cached --name-only | head -10 | sed 's/^/    /'
echo "  合计: $(git diff --cached --name-only | wc -l)"

git commit -q -m "feat: 收录部署与验证脚本 (probe/)

这些脚本记录了每个已修复问题的复现与验证手段，
包括 Edge TTS 403 根因、缓存键语义、限流边界等。
部署时按需运行，不必全跑。" 2>&1 | tail -2
echo "  提交: $(git log --oneline -1)"

echo ""
echo "=== 6. 最终状态 ==="
echo "  文件数: $(git ls-tree -r HEAD --name-only | wc -l)"
echo "  体积:   $(du -sh .git | cut -f1)"
