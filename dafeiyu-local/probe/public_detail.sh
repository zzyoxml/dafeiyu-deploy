#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== A. 状态文件（不该进任何仓库）==="
git ls-files | grep -E "state\.json|_state\.json|\.jsonl$" | sed 's/^/  /'
echo "  合计: $(git ls-files | grep -cE 'state\.json|_state\.json|\.jsonl$')"

echo ""
echo "=== B. 这些状态文件里有什么 ==="
for f in data/astrbot/dsh_emotion_state.json data/astrbot/qzone/state.json \
         data/astrbot/dsh_fatigue_state.json; do
  [ -f "$f" ] || continue
  echo "  $f ($(du -h "$f" | cut -f1)):"
  python3 -c "
import json,sys
try:
    d=json.load(open('$f',encoding='utf-8-sig'))
    if isinstance(d,dict):
        print('      顶层键:', list(d.keys())[:6])
except Exception as e:
    print('      解析失败',e)
" 2>/dev/null | head -3
done

echo ""
echo "=== C. 上游 LICENSE 情况（本地 repo/plugins 缺 LICENSE）==="
curl -s -m 15 "https://api.github.com/repos/nanbengxian-cyber/dafeiyu-qq-bot/license" \
  -H "Authorization: Bearer $(tr -d '\n\r ' < /root/.gh_token)" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
if 'license' in d and d['license']:
    print(f'  上游协议: {d[\"license\"][\"name\"]} ({d[\"license\"][\"spdx_id\"]})')
elif 'message' in d:
    print(f'  上游无 LICENSE 文件: {d[\"message\"][:40]}')
"
echo "  本地 repo/plugins 顶层文件:"
ls repo/plugins/ | head -5 | sed 's/^/    /'

echo ""
echo "=== D. patches 目录完整内容 ==="
du -sh patches/* 2>/dev/null | sed 's/^/  /'
git ls-files patches/ | sed 's/^/  /'

echo ""
echo "=== E. 绕登录代码规模（决定是否可公开）==="
echo "  napcat.mjs 体积: $(du -h patches/napcat.mjs.patched 2>/dev/null | cut -f1)"
echo "  这是反编译的 NapCat 主程序（3MB 混淆代码），含 1 处改动的登录校验绕过。"
echo "  公开它 = 公开一份改过的破解版 QQ 客户端逻辑。"
