"""在注入脚本里加 ServiceWorker 自愈：注销旧 SW 并清缓存

背景：
  前端注册了 ServiceWorker：
      navigator.serviceWorker.register("/webui/sw.js", { scope: "/webui/" })
  它对 /webui/* 是 Network First，但旧版本已缓存了旧页面，
  且 SW 自身更新要等页面全部关闭再开才生效 —— 用户普通 F5 无效。

做法：
  在 index.html 注入脚本最前面：
    1) 如果页面 HTML 里已带 v3 标记（说明服务端已下发新版），
       就主动注销 SW 并清空 caches，然后 reload 一次（用 sessionStorage 防循环）。
    2) 这样旧的 SW 会被彻底移除，以后不再拦截。
"""

import re
import shutil
import sys
import time

INDEX = "/app/napcat/static/index.html"
MARK = "<!-- NAPCAT_AUTOLOGIN -->"

src = open(INDEX, encoding="utf-8").read()

if MARK not in src:
    print("[sw] 未找到注入块")
    sys.exit(1)

inject = """<!-- NAPCAT_AUTOLOGIN -->
<script>
(function () {
  // v4 —— 加 ServiceWorker 自愈 + 放宽触发条件
  var BASE = "/webui";
  var KEY = "token";
  var SW_FLAG = "noauth_sw_cleared_v4";

  // ── 第一步：清理旧 ServiceWorker 与缓存 ──────────────────────
  // 旧 SW 会把登录页缓存住，导致服务端更新了 HTML 浏览器仍用旧的。
  // 只在第一次清，用 sessionStorage 防止死循环 reload。
  try {
    var cleared = sessionStorage.getItem(SW_FLAG);
    if (!cleared && navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
      navigator.serviceWorker.getRegistrations().then(function (regs) {
        var any = regs && regs.length > 0;
        if (!any) { sessionStorage.setItem(SW_FLAG, "1"); return; }
        Promise.all(regs.map(function (r) { return r.unregister(); }))
          .then(function () {
            if (window.caches && caches.keys) {
              return caches.keys().then(function (ks) {
                return Promise.all(ks.map(function (k) { return caches.delete(k); }));
              });
            }
          })
          .then(function () {
            console.log("[noauth] 旧 ServiceWorker 已注销，重新加载");
            sessionStorage.setItem(SW_FLAG, "1");
            window.location.reload();
          })
          .catch(function () { sessionStorage.setItem(SW_FLAG, "1"); });
      }).catch(function () {});
    } else {
      sessionStorage.setItem(SW_FLAG, "1");
    }
  } catch (e) {}

  // ── 第二步：自动登录 ─────────────────────────────────────────
  var path = window.location.pathname;
  if (path.indexOf(BASE + "/qq_login") === 0) return;  // 已在主界面

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
          try { localStorage.setItem(KEY, JSON.stringify(d.data.Credential)); } catch (e) {}
          console.log("[noauth] v4 凭证已保存，进入主界面");
          goMain();
        } else {
          console.warn("[noauth] v4 自动登录失败", d);
        }
      })
      .catch(function (e) { console.warn("[noauth] v4 请求异常", e); });
  }

  var has = false;
  try { has = !!localStorage.getItem(KEY); } catch (e) {}
  if (has) goMain(); else login();
})();
</script>
"""

pat = re.compile(re.escape(MARK) + r".*?</script>\s*", re.S)
if pat.search(src):
    src = pat.sub(inject, src, count=1)
    print("[sw] 注入块已替换为 v4")
else:
    print("[sw] FAIL")
    sys.exit(1)

shutil.copy2(INDEX, INDEX + ".bak-v4-" + time.strftime("%Y%m%d-%H%M%S"))
open(INDEX, "w", encoding="utf-8").write(src)
print("[write] done")
