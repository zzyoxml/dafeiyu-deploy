"""禁用 NapCat WebUI 的 ServiceWorker

为什么：
  index-BYES6ECA.js 末尾有：
    "serviceWorker" in navigator && window.addEventListener("load", () => {
      const e = "/webui/", t = `${e}sw.js`;
      navigator.serviceWorker.register(t, { scope: e })
        .then(r => console.log("SW registered: ", r))
        ...
    });

  这个 SW 会把 /webui/* 缓存住（Network First，但旧缓存仍在），
  导致服务端改了 index.html 浏览器还用旧的 —— 就是「怎么刷新都是登录页」的元凶。

做法：
  把 `"serviceWorker" in navigator` 改成 `false && ...`，
  并且不改动其它逻辑，SW 就永远不会再注册。
  另外在 index.html 的注入脚本里保留主动 unregister，清掉用户机器上已有的 SW。

这是标准做法：本地控制台类应用不需要离线缓存能力。
"""

import glob
import shutil
import sys
import time

TARGET_PATTERN = 'index-BYES6ECA.js'
p = None
for f in glob.glob("/app/napcat/static/assets/index-*.js"):
    s = open(f, encoding="utf-8", errors="ignore").read()
    if 'serviceWorker' in s and 'sw.js' in s and 'createRoot' in s or 'basename:"/webui/"' in s:
        p = f
        break

if not p:
    print("[sw] 未找到含 SW 注册的 index bundle")
    sys.exit(1)

print("[sw] target =", p)

s = open(p, encoding="utf-8", errors="ignore").read()
MARK = "NAPCAT_SW_DISABLED"

if MARK in s:
    print("[sw] 已禁用过，跳过")
    sys.exit(0)

old = '"serviceWorker"in navigator&&window.addEventListener("load"'
new = f'!1/*{MARK}*/&&window.addEventListener("load"'

if old not in s:
    # 变体：可能带空格
    alt = '"serviceWorker" in navigator && window.addEventListener("load"'
    if alt in s:
        old = alt
        new = f'!1/*{MARK}*/&&window.addEventListener("load"'
    else:
        print("[sw] FAIL 未匹配注册代码")
        i = s.find("serviceWorker")
        print("[sw] 附近:", repr(s[max(0, i - 60): i + 200]))
        sys.exit(1)

s = s.replace(old, new, 1)
print("[sw] 注册条件已改为 !1（永不注册）")

bak = p + ".bak-nosw-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(p, bak)
open(p, "w", encoding="utf-8", errors="ignore").write(s)
print("[write] done, backup", bak)
print("[verify] MARK 存在 =", MARK in open(p, encoding="utf-8", errors="ignore").read())
