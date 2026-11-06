"""NapCat WebUI 无密码 —— 一键完整补丁（幂等，可重复执行）

把最终版所有改动合并到一个脚本，供 wrapper 在每次容器启动时重放。

四处后端补丁：
  1. Yce          全局鉴权钩子 → 所有 API 直接放行
  2. vfe          /auth/check  → 恒返回成功
  3. gfe          /auth/login  → 跳过 hash 校验，任意输入可换合法凭证
  4. /webui 静态  去掉 maxAge:1d，对 html 加 no-store（否则前端改动被缓存 24h）

一处前端：
  index.html 注入 v4 脚本：
    - 注销旧 ServiceWorker 并清 caches（旧 SW 会缓存登录页，导致改动不生效）
    - 自动调 /auth/login 换凭证写 localStorage
    - 跳转到 /webui/qq_login（注意：必须带 /webui 前缀，裸 /qq_login 会 404）

实测验证过的行为：
  curl /api/auth/check  {}                → {"code":0,...}
  curl /api/auth/login  {"hash":"noauth"} → {"code":0,"data":{"Credential":...}}
  curl /webui/                            → Cache-Control: no-store
"""

import json
import re
import shutil
import sys
import time

MJ = "/app/napcat/napcat.mjs"
INDEX = "/app/napcat/static/index.html"
TS = time.strftime("%Y%m%d-%H%M%S")

src = open(MJ, encoding="utf-8", errors="surrogateescape").read()
changed = 0

# ── 1. 全局钩子 ──────────────────────────────────────────────
if "PATCHED: WebUI 已设为无密码" not in src:
    old = 'async function Yce(t, e, n) {\n  if (t.url === "/auth/login" ||'
    new = (
        'async function Yce(t, e, n) {\n'
        '  return n();  /* PATCHED: WebUI 已设为无密码，全部放行 */\n'
        '  if (t.url === "/auth/login" ||'
    )
    if old in src:
        src = src.replace(old, new, 1)
        changed += 1
        print("[1/4] Yce 鉴权钩子已放行")

# ── 2. /auth/check ──────────────────────────────────────────
if "return me(e, null);  /* PATCHED: 无密码 */" not in src:
    old = 'vfe = async (t, e) => {\n  const n = t.headers.authorization;'
    new = 'vfe = async (t, e) => {\n  return me(e, null);  /* PATCHED: 无密码 */\n  const n = t.headers.authorization;'
    if old in src:
        src = src.replace(old, new, 1)
        changed += 1
        print("[2/4] /auth/check 已恒成功")

# ── 3. /auth/login hash 校验 ────────────────────────────────
if "PATCHED: 无密码，跳过校验" not in src:
    old = 'if (!rn.comparePasswordHash(s, r))\n      return ne(e, "token is invalid");'
    new = 'if (false && !rn.comparePasswordHash(s, r))  /* PATCHED: 无密码，跳过校验 */\n      return ne(e, "token is invalid");'
    if old in src:
        src = src.replace(old, new, 1)
        changed += 1
        print("[3/4] /auth/login 校验已绕过")
    else:
        alt = "if (!rn.comparePasswordHash(s, r))"
        if alt in src:
            src = src.replace(
                alt,
                "if (false && !rn.comparePasswordHash(s, r))  /* PATCHED: 无密码，跳过校验 */",
                1,
            )
            changed += 1
            print("[3/4] login 宽松匹配成功")

# ── 4. /webui 静态中间件禁缓存 ──────────────────────────────
if "PATCHED_WEBUI_NOCACHE" not in src:
    i = src.find('Ln.use("/webui", nu.static')
    if i > 0:
        seg = src[i : i + 140]
        end = seg.find("}))")
        if end > 0:
            old_full = seg[: end + 3]
            new_full = (
                'Ln.use("/webui", nu.static(e.staticPath, {'
                ' /* PATCHED_WEBUI_NOCACHE */ '
                'setHeaders: (res, fp) => {'
                ' if (/\\.html?$/i.test(fp)) {'
                ' res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");'
                ' res.setHeader("Pragma", "no-cache");'
                ' res.setHeader("Expires", "0");'
                ' }'
                ' }'
                ' }))'
            )
            src = src.replace(old_full, new_full, 1)
            changed += 1
            print("[4/4] /webui 静态中间件已禁缓存")

if changed:
    bak = MJ + ".bak-full-" + TS
    shutil.copy2(MJ, bak)
    open(MJ, "w", encoding="utf-8", errors="surrogateescape").write(src)
    print(f"[write] napcat.mjs 更新 {changed} 处，备份 {bak}")
else:
    print("[write] napcat.mjs 无需改动")

# ── 前端注入 ────────────────────────────────────────────────
MARK_FE = "<!-- NAPCAT_AUTOLOGIN -->"

inject = """<!-- NAPCAT_AUTOLOGIN -->
<script>
(function () {
  // v4 —— ServiceWorker 自愈 + 自动登录
  var BASE = "/webui";   // 服务端只把 /webui/* 交给 SPA，裸路径会 404
  var KEY = "token";
  var SW_FLAG = "noauth_sw_cleared_v4";

  // 旧 ServiceWorker 会缓存登录页，必须先清掉，否则改了什么都不会生效
  try {
    var cleared = sessionStorage.getItem(SW_FLAG);
    if (!cleared && navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
      navigator.serviceWorker.getRegistrations().then(function (regs) {
        if (!regs || !regs.length) { sessionStorage.setItem(SW_FLAG, "1"); return; }
        Promise.all(regs.map(function (r) { return r.unregister(); }))
          .then(function () {
            if (window.caches && caches.keys) {
              return caches.keys().then(function (ks) {
                return Promise.all(ks.map(function (k) { return caches.delete(k); }));
              });
            }
          })
          .then(function () {
            sessionStorage.setItem(SW_FLAG, "1");
            window.location.reload();
          })
          .catch(function () { sessionStorage.setItem(SW_FLAG, "1"); });
      }).catch(function () {});
    } else {
      sessionStorage.setItem(SW_FLAG, "1");
    }
  } catch (e) {}

  var path = window.location.pathname;
  if (path.indexOf(BASE + "/qq_login") === 0) return;

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
          goMain();
        } else {
          console.warn("[noauth] 自动登录失败", d);
        }
      })
      .catch(function (e) { console.warn("[noauth] 请求异常", e); });
  }

  var has = false;
  try { has = !!localStorage.getItem(KEY); } catch (e) {}
  if (has) goMain(); else login();
})();
</script>
"""

cur = open(INDEX, encoding="utf-8").read()
if "v4 —— ServiceWorker 自愈" not in cur:
    if MARK_FE in cur:
        pat = re.compile(re.escape(MARK_FE) + r".*?</script>\s*", re.S)
        cur = pat.sub(inject, cur, count=1)
        print("[fe] 注入块已升级为 v4")
    elif "</head>" in cur:
        cur = cur.replace("</head>", inject + "</head>", 1)
        print("[fe] 首次注入 v4")
    else:
        print("[fe] FAIL 找不到 </head>")
        sys.exit(1)
    shutil.copy2(INDEX, INDEX + ".bak-full-" + TS)
    open(INDEX, "w", encoding="utf-8").write(cur)
    print("[fe] index.html 已写入")
else:
    print("[fe] 已是 v4，跳过")

print("[done] 全部补丁就绪")

# ── 5. 禁用 ServiceWorker 注册 ──────────────────────────────
# 为什么必须做：SW 会缓存 /webui/*，导致 index.html 改动不生效，
# 用户怎么刷新都看不到新版（表现为「一直是登录页」）。
import glob

SW_MARK = "NAPCAT_SW_DISABLED"
sw_done = False
for f in glob.glob("/app/napcat/static/assets/index-*.js"):
    try:
        t = open(f, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    if "serviceWorker" not in t or "sw.js" not in t:
        continue
    if SW_MARK in t:
        print("[sw] 已禁用过（%s）" % f.split("/")[-1])
        sw_done = True
        break
    for old_sw, new_sw in (
        ('"serviceWorker"in navigator&&window.addEventListener("load"',
         '!1/*' + SW_MARK + '*/&&window.addEventListener("load"'),
        ('"serviceWorker" in navigator && window.addEventListener("load"',
         '!1/*' + SW_MARK + '*/&&window.addEventListener("load"'),
    ):
        if old_sw in t:
            t = t.replace(old_sw, new_sw, 1)
            shutil.copy2(f, f + ".bak-nosw-" + TS)
            open(f, "w", encoding="utf-8", errors="ignore").write(t)
            print("[sw] %s 的 SW 注册已禁用" % f.split("/")[-1])
            sw_done = True
            break
    if sw_done:
        break

if not sw_done:
    print("[sw] 未找到需要禁用的 SW 注册（可能已处理）")

# ── 6. bundle 换名，绕过浏览器强缓存 ────────────────────────
# 只改内容不改文件名时，浏览器按 hash 文件名强缓存，永远拿旧 JS。
import os

ASSETS = "/app/napcat/static/assets"
OLD_B, NEW_B = "index-BYES6ECA.js", "index-BYES6ECA-noauth.js"
op, np_ = os.path.join(ASSETS, OLD_B), os.path.join(ASSETS, NEW_B)

if os.path.exists(op):
    shutil.copy2(op, np_)  # 每次都刷新，保证与源同步
    n = 0
    for f in [os.path.join("/app/napcat/static", "index.html")] + glob.glob(
        os.path.join(ASSETS, "*.js")
    ) + glob.glob(os.path.join(ASSETS, "*.css")):
        if not os.path.isfile(f) or os.path.basename(f) == OLD_B:
            continue
        t = open(f, encoding="utf-8", errors="ignore").read()
        if OLD_B not in t:
            continue
        n += t.count(OLD_B)
        open(f, "w", encoding="utf-8", errors="ignore").write(t.replace(OLD_B, NEW_B))
    print("[rename] bundle 已换名，更新 %d 处引用" % n)
else:
    print("[rename] 源 bundle 不存在，跳过")

# ── 7. SW 模板换成自毁版 ────────────────────────────────────
SWT = "/app/napcat/static/sw_template.js"
SD_MARK = "NAPCAT_SW_SELFDESTRUCT"
try:
    cur_sw = open(SWT, encoding="utf-8", errors="ignore").read()
except OSError:
    cur_sw = None

if cur_sw is not None and SD_MARK not in cur_sw:
    payload = """/* NAPCAT_SW_SELFDESTRUCT —— 自毁型 Service Worker
 *
 * NapCat 默认 SW 缓存 /webui/*，导致前端更新无法生效。
 * 此版本不缓存、不拦截请求，安装后立即注销自己。
 * 保留 {{VERSION}} 占位符，服务端会替换为实际版本号。
 */
const VERSION = '{{VERSION}}';

self.addEventListener('install', () => { self.skipWaiting(); });

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    } catch (e) {}
    try { await self.clients.claim(); } catch (e) {}
    try { await self.registration.unregister(); } catch (e) {}
  })());
});

// 不注册 fetch 监听器：所有请求直连网络。
"""
    shutil.copy2(SWT, SWT + ".bak-selfdestruct-" + TS)
    open(SWT, "w", encoding="utf-8").write(payload)
    print("[sw] sw_template.js 已替换为自毁版")
elif cur_sw is not None:
    print("[sw] sw_template.js 已是自毁版")
