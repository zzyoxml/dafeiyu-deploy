"""修正前端自动登录脚本：跳转路径必须带 /webui 前缀

根因：
  NapCat 的服务端只把 /webui/* 交给 SPA 处理：
      Ln.all(/\\/webui\\/(.*)/, (f, m) => m.sendFile(index.html))
  /qq_login 这种裸路径会 404。
  而 react-router 的 navigate() 是相对 basename 的，所以前端源码里写
  h("/qq_login") 是对的；我用了 window.location.replace 就必须自己补 /webui。

做法：把 index.html 里已注入的脚本整段替换成修正版。
"""

import re
import shutil
import sys
import time

INDEX = "/app/napcat/static/index.html"
MARK = "<!-- NAPCAT_AUTOLOGIN -->"

src = open(INDEX, encoding="utf-8").read()

if MARK not in src:
    print("[fix] 没找到已注入的脚本，需要先跑 patch_noauth_full.py")
    sys.exit(1)

inject = """<!-- NAPCAT_AUTOLOGIN -->
<script>
(function () {
  // 注意：NapCat 服务端只把 /webui/* 交给 SPA（见 Ln.all(/\\/webui\\/(.*)/)），
  // 裸 /qq_login 会 404 —— 这里所有跳转都必须带 /webui 前缀。
  var BASE = "/webui";
  var KEY = "token";

  function hasCred() {
    try { return !!localStorage.getItem(KEY); } catch (e) { return false; }
  }

  function goMain() {
    var p = window.location.pathname;
    // 已经在主界面就别再跳，避免循环
    if (p.indexOf("/webui/qq_login") === 0 || (p.indexOf("/webui/web_login") < 0)) return;
    window.location.replace(BASE + "/qq_login");
  }

  function login() {
    fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ hash: "noauth" }),
    })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (d && d.code === 0 && d.data && d.data.Credential) {
          try {
            localStorage.setItem(KEY, JSON.stringify(d.data.Credential));
            console.log("[noauth] 凭证已保存，进入主界面");
          } catch (e) { console.warn("[noauth] 保存失败", e); }
          goMain();
        } else {
          console.warn("[noauth] 自动登录失败", d);
        }
      })
      .catch(function (e) { console.warn("[noauth] 请求异常", e); });
  }

  // 只在登录页触发一次性自动登录
  if (window.location.pathname.indexOf("/webui/web_login") === 0) {
    if (hasCred()) goMain();
    else login();
  }
})();
</script>
"""

# 用正则把旧的注入块整段换成新的（从 MARK 到 </script>）
pat = re.compile(re.escape(MARK) + r".*?</script>\s*", re.S)
if pat.search(src):
    src = pat.sub(inject, src, count=1)
    print("[fix] 旧脚本已替换为修正版")
else:
    print("[fix] FAIL 无法定位旧脚本块")
    sys.exit(1)

shutil.copy2(INDEX, INDEX + ".bak-fixpath-" + time.strftime("%Y%m%d-%H%M%S"))
open(INDEX, "w", encoding="utf-8").write(src)
print("[write] index.html 已更新")

# 顺带把持久化副本也更新，方便重建后重放
print("[note] 请同步更新 patch_noauth_full.py 里的注入脚本")
