"""修正前端自动登录：放宽触发条件 + 绕开缓存

两个问题：
  1. index.html 带 Cache-Control: max-age=86400，浏览器可能还在用旧版本（没有注入脚本）。
     → 给注入脚本加一个版本号，并在脚本里检测「旧 localStorage 里有没有凭证」无论如何都跑。
  2. 原脚本只在 pathname 以 /webui/web_login 开头时触发，
     但用户实际打开的是 /webui/（根路径，SPA 内部再路由到 web_login），
     所以脚本没执行。
     → 改成：只要不是 /webui/qq_login（主界面）就自动登录。
"""

import re
import shutil
import sys
import time

INDEX = "/app/napcat/static/index.html"
MARK = "<!-- NAPCAT_AUTOLOGIN -->"

src = open(INDEX, encoding="utf-8").read()

if MARK not in src:
    print("[fix] 未找到注入块")
    sys.exit(1)

inject = """<!-- NAPCAT_AUTOLOGIN -->
<script>
(function () {
  // v3 —— 放宽触发条件 + 支持根路径 /webui/
  //
  // 关键事实：
  //   * NapCat 服务端只把 /webui/* 交给 SPA，裸 /qq_login 会 404。
  //   * 用户常直接打开 /webui/（根），SPA 内部再路由到 web_login，
  //     所以不能只判断 /webui/web_login。
  //   * /webui/qq_login 登录后才到，见到它就说明已登录，不再干预。
  var BASE = "/webui";
  var KEY = "token";

  var path = window.location.pathname;
  if (path.indexOf(BASE + "/qq_login") === 0) return;  // 已在主界面

  function saveCred(c) {
    try { localStorage.setItem(KEY, JSON.stringify(c)); return true; }
    catch (e) { return false; }
  }

  function goMain() { window.location.replace(BASE + "/qq_login"); }

  function login() {
    fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ hash: "noauth" }),
    })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (d && d.code === 0 && d.data && d.data.Credential) {
          saveCred(d.data.Credential);
          console.log("[noauth] v3 凭证已保存，进入主界面");
          goMain();
        } else {
          console.warn("[noauth] v3 自动登录失败", d);
        }
      })
      .catch(function (e) { console.warn("[noauth] v3 请求异常", e); });
  }

  // 已有凭证 → 直接进主界面；没有 → 自动换一个
  var has = false;
  try { has = !!localStorage.getItem(KEY); } catch (e) {}
  if (has) goMain(); else login();
})();
</script>
"""

pat = re.compile(re.escape(MARK) + r".*?</script>\s*", re.S)
if pat.search(src):
    src = pat.sub(inject, src, count=1)
    print("[fix] 注入块已替换为 v3")
else:
    print("[fix] FAIL 无法定位")
    sys.exit(1)

shutil.copy2(INDEX, INDEX + ".bak-v3-" + time.strftime("%Y%m%d-%H%M%S"))
open(INDEX, "w", encoding="utf-8").write(src)
print("[write] done")
