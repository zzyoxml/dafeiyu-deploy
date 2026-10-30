"""NapCat WebUI 免登录最终方案：登录页自动提交

前端已支持 /web_login?token=xxx 预填输入框（源码确认）：
  const C = new URLSearchParams(location.search).get("token")
  const [i, N] = useState(C || "")

但它只预填、不自动提交，而且守卫要求 localStorage 里有凭证。
所以在 index.html 注入：检测到 ?token= 且在登录页时，等 React 渲染完
自动触发「登录」按钮；或者更稳的做法——直接调后端 /auth/login 拿凭证
写进 localStorage，然后跳转 /qq_login。

后者不依赖 DOM 结构，React 改了也不会坏。
"""

import base64
import json
import shutil
import sys
import time

INDEX = "/app/napcat/static/index.html"
BAK = INDEX + ".bak-autologin-" + time.strftime("%Y%m%d-%H%M%S")

MARK = "<!-- NAPCAT_AUTOLOGIN -->"

# 真实 token（从 webui.json 读，运行时由 wrapper 传入会让脚本复杂，
# 这里直接写死；改 token 时同步改这里）
TOKEN = "<你的NapCat_Token>"
KEY = "token"

inject = f"""{MARK}
<script>
(function () {{
  var TOKEN = {json.dumps(TOKEN)};
  var KEY = {json.dumps(KEY)};
  var path = window.location.pathname;

  // 只在登录页生效，避免干扰其它页面
  var isLoginPage = path.indexOf("web_login") >= 0;

  function saveCred(cred) {{
    try {{
      localStorage.setItem(KEY, JSON.stringify(cred));
      console.log("[autologin] 凭证已保存");
      return true;
    }} catch (e) {{
      console.warn("[autologin] 保存失败", e);
      return false;
    }}
  }}

  function loginThenGo() {{
    // 后端已打成无密码：/auth/login 的 hash 校验被绕过
    fetch("/api/auth/login", {{
      method: "POST",
      headers: {{ "Content-Type": "application/json" }},
      body: JSON.stringify({{ hash: "noauth" }}),
    }})
      .then(function (r) {{ return r.json(); }})
      .then(function (d) {{
        if (d && d.code === 0 && d.data && d.data.Credential) {{
          saveCred(d.data.Credential);
          console.log("[autologin] 登录成功，跳转 /qq_login");
          if (isLoginPage) window.location.replace("/qq_login");
        }} else {{
          console.warn("[autologin] 后端返回异常", d);
        }}
      }})
      .catch(function (e) {{ console.warn("[autologin] 请求失败", e); }});
  }}

  if (isLoginPage) {{
    // 登录页：直接自动登录（已经有凭证就不用）
    var has = false;
    try {{ has = !!localStorage.getItem(KEY); }} catch (e) {{}}
    if (!has) loginThenGo();
    else window.location.replace("/qq_login");
  }}
}})();
</script>
"""

src = open(INDEX, encoding="utf-8").read()

if MARK in src:
    print("[inject] 已存在，跳过")
    sys.exit(0)

anchor = "</head>"
if anchor not in src:
    print("[inject] FAIL 找不到 </head>")
    sys.exit(1)

src = src.replace(anchor, inject + anchor, 1)
shutil.copy2(INDEX, BAK)
print("[backup]", BAK)
open(INDEX, "w", encoding="utf-8").write(src)
print("[write] index.html 已注入自动登录脚本")
print("[note] token =", TOKEN)
