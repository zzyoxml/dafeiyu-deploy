"""最终修正 HTML 缓存：改 serve-static 的 setHeaders

真实链路（按注册顺序）：
  1. nu.static(A, { maxAge: "1d" })   ← 先命中，/webui/ 由它的 index 解析返回 index.html
  2. Ln.all(/\\/webui\\/(.*)/, sendFile) ← 根本走不到
所以之前 setHeader 无效，缓存头是 serve-static 打的。

做法：给 static 加 setHeaders，对 .html 清掉缓存头；
带 hash 的 /assets/* 仍保留 1d 强缓存（它们内容变了文件名也会变）。
"""

import shutil
import sys
import time

P = "/app/napcat/napcat.mjs"
src = open(P, encoding="utf-8", errors="surrogateescape").read()

MARK = "PATCHED: static html 禁缓存"

if MARK in src:
    print("[static] 已有补丁，跳过")
    sys.exit(0)

old = 'nu.static(A, { maxAge: "1d" })'
new = (
    'nu.static(A, { maxAge: "1d", '
    'setHeaders: (res, p) => { /* PATCHED: static html 禁缓存 */ '
    'if (/\\.html?$/i.test(p)) { '
    'res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"); '
    'res.setHeader("Pragma", "no-cache"); '
    'res.setHeader("Expires", "0"); '
    'res.removeHeader("ETag"); '
    'res.removeHeader("Last-Modified"); } } })'
)

if old not in src:
    print("[static] FAIL 未匹配 nu.static(A, ...)")
    i = src.find("nu.static(A")
    if i > 0:
        print("实际:", repr(src[i: i + 120]))
    sys.exit(1)

src = src.replace(old, new, 1)
print("[static] setHeaders 已插入")

# 同时修掉之前写错的 Ge（如果还在）
if "const html = Ge.readFileSync" in src:
    src = src.replace("const html = Ge.readFileSync", "const html = _f.readFileSync", 1)
    print("[fix] Ge -> _f 已修正")

bak = P + ".bak-static-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(P, bak)
open(P, "w", encoding="utf-8", errors="surrogateescape").write(src)
print("[write] done, backup", bak)
