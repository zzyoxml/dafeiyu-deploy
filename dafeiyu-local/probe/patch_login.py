"""补丁 v3：连 /auth/login 也放行，任意 hash 都能换到合法凭证。

之前只改了 Yce（全局钩子）和 vfe（/auth/check），但 /auth/login 里还有：
    if (!rn.comparePasswordHash(s, r)) return ne(e, "token is invalid");
这条没被绕过，所以前端登录页仍然拿不到凭证。
"""

import shutil
import sys
import time

P = "/app/napcat/napcat.mjs"

src = open(P, encoding="utf-8", errors="surrogateescape").read()

# 在 login 的 hash 校验处短路：把校验条件改成永远不成立，从而跳过 return
old = 'if (!rn.comparePasswordHash(s, r))\n      return ne(e, "token is invalid");'
new = 'if (false && !rn.comparePasswordHash(s, r))  /* PATCHED: 无密码，跳过校验 */\n      return ne(e, "token is invalid");'

if old in src:
    src = src.replace(old, new, 1)
    print("[patch3] /auth/login 校验已绕过")
else:
    # 尝试更宽松的匹配
    alt_old = 'if (!rn.comparePasswordHash(s, r))'
    if alt_old in src:
        src = src.replace(alt_old, 'if (false && !rn.comparePasswordHash(s, r))  /* PATCHED: 无密码 */', 1)
        print("[patch3] 宽松匹配成功")
    else:
        print("[patch3] FAIL 找不到 comparePasswordHash 校验")
        sys.exit(1)

BAK = P + ".bak-login-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(P, BAK)
print("[backup]", BAK)

open(P, "w", encoding="utf-8", errors="surrogateescape").write(src)
print("[write] done")
print("[count] PATCHED 出现次数 =", src.count("PATCHED"))
