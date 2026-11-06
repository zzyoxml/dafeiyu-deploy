#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 移除 patches/napcat.mjs.patched（绕过登录的破解代码）==="
git rm --cached patches/napcat.mjs.patched -q 2>/dev/null && echo "  已从 git 移除"
cat >> .gitignore <<'EOF'

# ─────────────── 公开仓库额外排除 ───────────────
# 1) NapCat 主程序打过「跳过登录校验」补丁，属破解改动，不公开。
#    复现方式见 patches/README.md
patches/napcat.mjs.patched
patches/*.mjs.patched

# 2) 群聊语料库（真人 uid + 原话 + 群号），隐私数据
data/astrbot/plugins/dsh-slang/slang.json
data/astrbot/plugins/dsh-slang/shadow.json

# 3) 插件运行状态（含群号）
data/astrbot/dsh_*_state.json
data/astrbot/dsh_*_events.jsonl
data/astrbot/qzone/

# 4) 个人化数据
data/astrbot/plugins/dsh-selfworth/data/
data/astrbot/plugins/dsh-quote/test_quote.py
EOF
echo "  已追加排除规则"

echo ""
echo "=== 2. 移除状态文件与个人数据 ==="
git rm --cached -q \
  data/astrbot/dsh_emotion_state.json \
  data/astrbot/dsh_fatigue_state.json \
  data/astrbot/dsh_initiate_state.json \
  data/astrbot/dsh_interest_state.json \
  data/astrbot/dsh_mute_state.json \
  data/astrbot/dsh_proactive_state.json \
  data/astrbot/qzone/state.json \
  data/astrbot/plugins/dsh-slang/slang.json \
  data/astrbot/plugins/dsh-selfworth/data/selfworth.json \
  data/astrbot/plugins/dsh-quote/test_quote.py \
  2>/dev/null && echo "  已移除 10 个状态/隐私文件"

echo ""
echo "=== 3. 补上游 LICENSE（MIT 合规）==="
curl -s -m 20 -o /tmp/upstream_LICENSE \
  "https://raw.githubusercontent.com/nanbengxian-cyber/dafeiyu-qq-bot/main/LICENSE"
if [ -s /tmp/upstream_LICENSE ] && head -1 /tmp/upstream_LICENSE | grep -qi "MIT"; then
  cp /tmp/upstream_LICENSE LICENSE
  echo "  ✅ 已获取上游 MIT LICENSE"
  head -3 LICENSE | sed 's/^/    /'
else
  echo "  ⚠ 拉取失败，手写 MIT"
  cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 nanbengxian-cyber (upstream: dafeiyu-qq-bot)
Copyright (c) 2026 zzyoxml (local deployment & plugins)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
fi

echo ""
echo "=== 4. 写 patches/README.md 说明（替代破解文件）==="
mkdir -p patches
cat > patches/README.md <<'MDEOF'
# patches/

本目录**不包含** NapCat 主程序的补丁产物，仅说明打过什么补丁。

## 为什么不含

`napcat.mjs.patched` 是反编译并修改过的 NapCat 主程序（3MB），
其中包含「跳过 WebUI 登录密码校验」的改动。这类改动不适合公开分发，
所以没有提交。需要复现时请按下面说明自行处理。

## 打过哪些补丁

| 目标 | 改动 | 目的 |
|---|---|---|
| NapCat WebUI 登录 | `if (!rn.comparePasswordHash(s, r))` → `if (false && ...)` | 跳过密码校验（本地单机调试用） |
| AstrBot WebUI 静态资源 | `maxAge: "1d"` → 不缓存 | 刷新后能看到最新前端 |
| WSL2 代理 | `ProxyOverride` 加 `localhost;127.0.0.1;::1` | 让容器访问宿主机服务 |

## 复现

补丁本身是对 `napcat.mjs` 的字符串替换，定位方式见 `probe/` 下相关脚本。
MDEOF
echo "  ✅ 已写 patches/README.md"

echo ""
echo "=== 5. 重新暂存并检查 ==="
git add -A
echo "  文件数: $(git ls-files | wc -l)"
echo "  体积:   $(git ls-files -z | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1)"
