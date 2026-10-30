"""改用 res.send(读取的 HTML 字符串)，彻底摆脱 sendFile 的默认缓存头

sendFile 内部会自己设置 Cache-Control（默认 max-age=86400），
即使先 setHeader 也会被覆盖。直接发字符串就没有这个问题。
"""

import shutil
import sys
import time

P = "/app/napcat/napcat.mjs"
src = open(P, encoding="utf-8", errors="surrogateescape").read()

MARK = "PATCHED: HTML 禁缓存 v2"
if MARK in src:
    print("[v2] 已有补丁，跳过")
    sys.exit(0)

# 先把 v1 补丁回退掉
old_v1 = '''  Ln.all(/\\/webui\\/(.*)/, (f, m) => {
    /* PATCHED: HTML 禁缓存，否则前端改动要等 24 小时才生效 */
    m.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
    m.setHeader("Pragma", "no-cache");
    m.setHeader("Expires", "0");
    m.sendFile(d);
  })'''
old_plain = '''  Ln.all(/\\/webui\\/(.*)/, (f, m) => {
    m.sendFile(d);
  })'''

new = '''  Ln.all(/\\/webui\\/(.*)/, (f, m) => {
    /* PATCHED: HTML 禁缓存 v2 —— 用 send 字符串，避开 sendFile 自带的 max-age=86400 */
    try {
      const html = Ge.readFileSync(d, "utf8");
      m.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
      m.setHeader("Pragma", "no-cache");
      m.setHeader("Expires", "0");
      m.removeHeader("ETag");
      m.removeHeader("Last-Modified");
      m.type("html").send(html);
    } catch (err) {
      m.sendFile(d);
    }
  })'''

if old_v1 in src:
    src = src.replace(old_v1, new, 1)
    print("[v2] 已从 v1 升级")
elif old_plain in src:
    src = src.replace(old_plain, new, 1)
    print("[v2] 已替换原始路由")
else:
    print("[v2] FAIL 未匹配路由")
    i = src.find("sendFile(d)")
    if i > 0:
        print("实际:", repr(src[i - 120: i + 60]))
    sys.exit(1)

bak = P + ".bak-cache2-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(P, bak)
open(P, "w", encoding="utf-8", errors="surrogateescape").write(src)
print("[v2] 已写入，备份", bak)
print("[v2] 确认 Ge 是 fs 别名:", "Ge.readFileSync" in open(P, encoding="utf-8", errors="surrogateescape").read())
