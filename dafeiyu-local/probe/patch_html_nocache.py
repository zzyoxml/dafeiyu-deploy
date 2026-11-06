"""给 /webui/* 的 HTML 响应禁用缓存

原因：
  m.sendFile(index.html) 默认带 Cache-Control: public, max-age=86400，
  导致浏览器 24 小时内一直用旧的 index.html（没有我注入的自动登录脚本），
  F5 也不管用。改成 no-store 后每次导航都取最新 HTML。

注意：
  /webui/assets/* 那些带 hash 的静态资源仍需强缓存，所以只改 HTML 这一个路由。
"""

import shutil
import sys
import time

P = "/app/napcat/napcat.mjs"
src = open(P, encoding="utf-8", errors="surrogateescape").read()

MARK = "PATCHED: HTML 禁缓存"
if MARK in src:
    print("[cache] 已有补丁，跳过")
    sys.exit(0)

old = '''  Ln.all(/\\/webui\\/(.*)/, (f, m) => {
    m.sendFile(d);
  })'''

new = '''  Ln.all(/\\/webui\\/(.*)/, (f, m) => {
    /* PATCHED: HTML 禁缓存，否则前端改动要等 24 小时才生效 */
    m.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
    m.setHeader("Pragma", "no-cache");
    m.setHeader("Expires", "0");
    m.sendFile(d);
  })'''

if old not in src:
    print("[cache] FAIL 未匹配路由")
    print("[cache] 实际片段：")
    i = src.find("/webui/(.*)/")
    if i > 0:
        print(repr(src[i - 60: i + 150]))
    sys.exit(1)

src = src.replace(old, new, 1)

bak = P + ".bak-cache-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(P, bak)
open(P, "w", encoding="utf-8", errors="surrogateescape").write(src)
print("[cache] HTML 响应已设为 no-store")
print("[backup]", bak)
