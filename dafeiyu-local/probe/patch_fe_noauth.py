"""NapCat WebUI 免登录：前端自动注入凭证

原理：
  前端 web_login 页面在 token 输入框为空时直接弹「请输入token」，不请求后端。
  首页守卫读 localStorage 的 token 判断是否已登录。
  所以只要在页面加载前把一个「看起来合法」的凭证塞进 localStorage，
  前端守卫就认为已登录，直接进 /qq_login；而实际鉴权已被后端补丁全部放行，
  凭证内容是什么都无所谓。

做法：
  在 index.html </head> 前插入一小段脚本，向 localStorage 写入 token 键。
  键名从前端源码里确认（P.token / te.token）。
"""

import json
import re
import shutil
import sys
import time

INDEX = "/app/napcat/static/index.html"
BAK = INDEX + ".bak-noauth-" + time.strftime("%Y%m%d-%H%M%S")


def find_token_key() -> str:
    """从前端 bundle 里找 localStorage 用的 token 键名。"""
    import glob

    cand = []
    for f in glob.glob("/app/napcat/static/assets/*.js"):
        try:
            s = open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        # 形如 token:"token" 或 token:"napcat_token"
        for m in re.finditer(r'token\s*:\s*"([a-zA-Z0-9_\-]{2,32})"', s):
            cand.append(m.group(1))
    # 去重并统计
    from collections import Counter

    common = Counter(cand).most_common(10)
    print("[keys] 候选 localStorage 键名：", common)
    for name, _n in common:
        if "token" in name.lower():
            return name
    return "token"


KEY = find_token_key()
print("[keys] 采用键名 =", repr(KEY))

src = open(INDEX, encoding="utf-8").read()

MARK = "<!-- NAPCAT_NOAUTH_INJECT -->"
if MARK in src:
    print("[inject] 已存在，跳过")
    sys.exit(0)

# 构造一个永远不会被前端判空的凭证值：
# 前端只检查 localStorage 里 "有没有"、能不能 JSON.parse，不校验内容
# （校验在后端，后端已放行）。
cred_obj = {
    "Data": {"CreatedTime": 9999999999, "HashEncoded": "noauth"},
    "Hmac": "noauth",
}
cred_b64 = __import__("base64").b64encode(
    json.dumps(cred_obj, separators=(",", ":")).encode()
).decode()

inject = f"""{MARK}
<script>
(function () {{
  try {{
    var KEY = {json.dumps(KEY)};
    var CRED = {json.dumps(cred_b64)};
    // 前端用 JSON.stringify 存、JSON.parse 取，这里保持一致
    if (!localStorage.getItem(KEY)) {{
      localStorage.setItem(KEY, JSON.stringify(CRED));
      console.log("[noauth] 已注入免登录凭证 key=" + KEY);
    }}
  }} catch (e) {{ console.warn("[noauth] 注入失败", e); }}
}})();
</script>
"""

anchor = "</head>"
if anchor not in src:
    print("[inject] FAIL 找不到 </head>")
    sys.exit(1)

src = src.replace(anchor, inject + anchor, 1)

shutil.copy2(INDEX, BAK)
print("[backup]", BAK)
open(INDEX, "w", encoding="utf-8").write(src)
print("[write] index.html 已注入免登录脚本")
