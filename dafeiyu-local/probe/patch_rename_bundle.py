"""给改过的 index bundle 换文件名，强制浏览器重新拉取

问题：
  HTML 里引用的是 /webui/assets/index-BYES6ECA.js（文件名含内容 hash）。
  我修改了这个文件的内容（禁用 SW 注册），但文件名没变。
  浏览器和 SW 都按这个 URL 做强缓存，于是用户一直加载旧 JS，
  旧 JS 又去注册 SW，形成死循环 —— 刷新多少次都是登录页。

解法：
  把文件复制成新名字（带 NOAUTH 后缀），
  同时把 index.html 和所有引用它的 chunk 里的路径改过去。
  新 URL 从未被任何缓存记录过，浏览器必定从服务端拉取新内容。

注意：
  其它 chunk 里可能有 import 指向它，需要一并全局替换旧文件名。
"""

import glob
import os
import shutil
import sys
import time

STATIC = "/app/napcat/static"
ASSETS = os.path.join(STATIC, "assets")
OLD_NAME = "index-BYES6ECA.js"
NEW_NAME = "index-BYES6ECA-noauth.js"

old_path = os.path.join(ASSETS, OLD_NAME)
new_path = os.path.join(ASSETS, NEW_NAME)

if not os.path.exists(old_path):
    print("[rename] FAIL 源文件不存在:", old_path)
    sys.exit(1)

# 1. 复制成新名字
if not os.path.exists(new_path):
    shutil.copy2(old_path, new_path)
    print(f"[rename] 已复制 {OLD_NAME} -> {NEW_NAME}")
else:
    # 用当前源覆盖，保证内容最新
    shutil.copy2(old_path, new_path)
    print(f"[rename] 已刷新 {NEW_NAME}")

# 2. 确认新文件里 SW 是禁用的
content = open(new_path, encoding="utf-8", errors="ignore").read()
if "NAPCAT_SW_DISABLED" not in content:
    print("[rename] 警告：新文件里没有 SW 禁用标记！")
else:
    print("[rename] 新文件已确认 SW 禁用标记存在")

# 3. 全局替换：index.html + 所有 js/html 里对旧文件名的引用
replaced = 0
targets = [os.path.join(STATIC, "index.html")]
targets += glob.glob(os.path.join(ASSETS, "*.js"))
targets += glob.glob(os.path.join(ASSETS, "*.css"))

for f in targets:
    if not os.path.isfile(f):
        continue
    if os.path.basename(f) == OLD_NAME:
        continue  # 跳过源文件本身
    try:
        t = open(f, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    if OLD_NAME not in t:
        continue
    # 注意：NEW_NAME 里包含 OLD_NAME 的子串吗？
    # OLD_NAME = index-BYES6ECA.js
    # NEW_NAME = index-BYES6ECA-noauth.js
    # 不含，所以安全
    t2 = t.replace(OLD_NAME, NEW_NAME)
    cnt = t.count(OLD_NAME)
    shutil.copy2(f, f + ".bak-rename-" + time.strftime("%H%M%S"))
    open(f, "w", encoding="utf-8", errors="ignore").write(t2)
    replaced += cnt
    print(f"[rename] {os.path.basename(f)}: 替换 {cnt} 处")

print(f"[rename] 共替换 {replaced} 处引用")
print("[rename] done")
