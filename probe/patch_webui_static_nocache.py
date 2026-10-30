import re
import shutil
import sys
import time

p = "/app/napcat/napcat.mjs"
s = open(p, encoding="utf-8", errors="surrogateescape").read()

# 定位真正服务 /webui 的静态中间件
i = s.find('Ln.use("/webui", nu.static')
print("[locate] pos =", i)
if i < 0:
    print("[fail] 找不到")
    sys.exit(1)

print("[exact source]")
print(repr(s[i:i + 140]))

old = s[i:i + 140]
# 精确替换 maxAge: "1d" 这一段
m = re.search(r'maxAge:\s*"1d"', old)
if not m:
    print("[fail] 这个调用里没有 maxAge: 1d")
    sys.exit(1)

# 取到 })) 结束
end = old.find("}))")
if end < 0:
    print("[fail] 找不到结束括号")
    sys.exit(1)

old_full = old[:end + 3]
print("[old_full]", repr(old_full))

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

if old_full in s:
    s = s.replace(old_full, new_full, 1)
    print("[ok] 已替换")
else:
    print("[fail] 替换失败")
    sys.exit(1)

bak = p + ".bak-webui-nocache-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(p, bak)
open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)
print("[write] done, backup", bak)
print("[verify]", "PATCHED_WEBUI_NOCACHE" in open(p, encoding="utf-8", errors="surrogateescape").read())
