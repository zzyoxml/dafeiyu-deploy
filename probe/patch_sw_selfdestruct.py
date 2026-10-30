"""把 sw_template.js 换成「自毁型」ServiceWorker

问题：
  NapCat 的 SW 对 /webui/* 用 networkFirst，但用户机器上已装旧 SW，
  它会一直拦截导航请求并可能回退到旧缓存，导致：
    - 服务端已更新 index.html（含 v4 自动登录脚本）
    - 浏览器却仍拿到旧 HTML（没有脚本）
    - 于是永远停在登录页，怎么刷新都没用

解法：
  把 sw_template.js 替换成自毁脚本：
    1. install 时 skipWaiting 立即接管
    2. activate 时删掉所有 napcat 缓存，然后 unregister() 注销自己
    3. 不注册任何 fetch handler（不拦截任何请求）
  这样用户的旧 SW 一旦检测到新版本（浏览器会自动检查），
  就会更新成这个自毁版，然后彻底消失，之后页面完全走网络。
"""

import shutil
import sys
import time

P = "/app/napcat/static/sw_template.js"
MARK = "NAPCAT_SW_SELFDESTRUCT"

src = open(P, encoding="utf-8", errors="ignore").read()

if MARK in src:
    print("[sw] 已是自毁版，跳过")
    sys.exit(0)

payload = f"""/* {MARK} —— 自毁型 Service Worker
 *
 * 目的：NapCat 默认 SW 会缓存 /webui/*，导致前端更新无法生效。
 * 这个版本不做任何缓存、不拦截任何请求，安装后立即注销自己。
 *
 * 保留 {{VERSION}} 占位符：NapCat 服务端会用 Wu 变量替换它，
 * 每次这些值变化时浏览器才会认为 SW 有更新并重新安装。
 */
const VERSION = '{{{{VERSION}}}}';

self.addEventListener('install', (event) => {{
  // 不等旧 SW 退出，立刻进入 activating
  self.skipWaiting();
}});

self.addEventListener('activate', (event) => {{
  event.waitUntil((async () => {{
    // 1. 清掉所有缓存（包括旧 SW 建立的）
    try {{
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    }} catch (e) {{}}

    // 2. 接管现有页面，避免还要再刷新一次
    try {{
      await self.clients.claim();
    }} catch (e) {{}}

    // 3. 注销自己 —— 之后所有请求直连网络
    try {{
      await self.registration.unregister();
    }} catch (e) {{}}
  }})());
}});

// 故意不注册 fetch 监听器：不拦截任何请求，全部走网络。
"""

shutil.copy2(P, P + ".bak-selfdestruct-" + time.strftime("%Y%m%d-%H%M%S"))
open(P, "w", encoding="utf-8").write(payload)
print("[sw] sw_template.js 已替换为自毁版")
print("[sw] 大小:", len(payload), "字节（原", len(src), "字节）")
