"""彻底解决 HTML 缓存：把 nu.static 的 maxAge 去掉

为什么之前的 setHeaders 没用：
  serve-static 内部的执行顺序是「先按 maxAge 写 Cache-Control，再调 setHeaders」，
  所以我在 setHeaders 里改的 no-store 又被它自己覆盖回 max-age=86400。
  （实测响应头始终是 public, max-age=86400）

做法：
  去掉 maxAge → serve-static 不再写 Cache-Control，
  浏览器只能按 Last-Modified 做启发式缓存（文件刚改过，等于不缓存）。
  同时 setHeaders 里显式写 no-store，兜住其它浏览器策略。

影响：
  /webui/assets/* 带内容 hash，本来改了文件名就变，去掉强缓存只多一点本地请求，
  localhost 上可忽略；但换来的是前端改动立刻生效，不再被缓存坑。
"""

import shutil
import sys
import time

P = "/app/napcat/napcat.mjs"
src = open(P, encoding="utf-8", errors="surrogateescape").read()

MARK = "PATCHED: maxAge 已移除"

if MARK in src:
    print("[maxage] 已有补丁，跳过")
    sys.exit(0)

# 可能是 "1d"，也可能带 setHeaders（我上次加的）
old_candidates = [
    'nu.static(A, { maxAge: "1d", setHeaders: (res, p) => { /* PATCHED: static html 禁缓存 */ if (/\\.html?$/i.test(p)) { res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"); res.setHeader("Pragma", "no-cache"); res.setHeader("Expires", "0"); res.removeHeader("ETag"); res.removeHeader("Last-Modified"); } } })',
    'nu.static(A, { maxAge: "1d" })',
]

new = (
    'nu.static(A, { /* PATCHED: maxAge 已移除 */ '
    'setHeaders: (res, p) => { '
    'if (/\\.html?$/i.test(p)) { '
    'res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0"); '
    'res.setHeader("Pragma", "no-cache"); '
    'res.setHeader("Expires", "0"); '
    '} '
    '} })'
)

hit = None
for cand in old_candidates:
    if cand in src:
        hit = cand
        break

if not hit:
    print("[maxage] FAIL 未匹配 nu.static 调用")
    i = src.find("nu.static(A")
    if i > 0:
        print("实际:", repr(src[i: i + 300]))
    sys.exit(1)

src = src.replace(hit, new, 1)
print("[maxage] 已替换:", "（含上次 setHeaders）" if "setHeaders" in hit else "（原始 maxAge 1d）")

bak = P + ".bak-maxage-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(P, bak)
open(P, "w", encoding="utf-8", errors="surrogateescape").write(src)
print("[write] done, backup", bak)
