#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 两个提交各自包含什么 ==="
echo "── 072d3d1 feat(stt) ──"
git show --stat --oneline 072d3d1 | head -12 | sed 's/^/  /'

echo ""
echo "── 53bf73b feat(dsh-stt-clean) ──"
git show --stat --oneline 53bf73b | head -10 | sed 's/^/  /'

echo ""
echo "=== 2. 关键脚本是否进了仓库 ==="
for f in probe/install_stt.sh probe/enable_stt.py probe/test_stt_direct.py \
         probe/asr_survey.sh probe/stt_detail.sh; do
  git ls-files "$f" | grep -q . && echo "  ✅ $f" || echo "  ❌ 缺 $f"
done

echo ""
echo "=== 3. probe 目录里 stt 相关的都在吗 ==="
git ls-files probe/ | grep -i stt | sed 's/^/  /'

echo ""
echo "=== 4. 工作区是否干净 ==="
git status --porcelain | sed 's/^/  /' || true
echo "  $(git status --porcelain | wc -l) 个改动"
