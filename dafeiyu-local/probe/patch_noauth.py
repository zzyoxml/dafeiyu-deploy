"""把 NapCat WebUI 改成无密码：全局鉴权钩子直接放行，/auth/check 恒返回成功。"""

import shutil
import sys
import time

P = "/app/napcat/napcat.mjs"
BAK = P + ".bak-noauth-" + time.strftime("%Y%m%d-%H%M%S")

src = open(P, encoding="utf-8", errors="surrogateescape").read()
orig_len = len(src)

# ── 补丁 1：全局鉴权钩子 Yce —— 直接放行所有请求 ────────────────────
old1 = (
    'async function Yce(t, e, n) {\n'
    '  if (t.url === "/auth/login" ||'
)
new1 = (
    'async function Yce(t, e, n) {\n'
    '  return n();  /* PATCHED: WebUI 已设为无密码，全部放行 */\n'
    '  if (t.url === "/auth/login" ||'
)

# ── 补丁 2：/auth/check（vfe）—— 恒返回成功 ─────────────────────────
old2 = 'vfe = async (t, e) => {\n  const n = t.headers.authorization;'
new2 = 'vfe = async (t, e) => {\n  return me(e, null);  /* PATCHED: 无密码 */\n  const n = t.headers.authorization;'

count = 0
if old1 in src:
    src = src.replace(old1, new1, 1)
    print("[patch1] Yce 鉴权钩子已放行")
    count += 1
else:
    print("[patch1] 未匹配 Yce —— 尝试宽松匹配")

if old2 in src:
    src = src.replace(old2, new2, 1)
    print("[patch2] /auth/check 恒成功")
    count += 1
else:
    print("[patch2] 未匹配 vfe")

if count == 0:
    print("FAIL: 两处都没改到，放弃")
    sys.exit(1)

# 备份并写回
shutil.copy2(P, BAK)
print("[backup]", BAK)
open(P, "w", encoding="utf-8", errors="surrogateescape").write(src)
print(f"[write] {orig_len} -> {len(src)} bytes (+{len(src)-orig_len})")
