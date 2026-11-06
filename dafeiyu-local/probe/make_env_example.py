import re

src = "/opt/dafeiyu/robot.env"
dst = "/opt/dafeiyu/robot.env.example"

SENSITIVE_PREFIX = (
    "DSH_IMAGEGEN_KEY", "DSH_WEB_SEARCH_KEY", "DSH_WEB_ANYSEARCH_KEY",
    "DSH_IMG_API_KEY", "DSH_VOICE_API_KEY", "DSH_QZONE_COOKIE",
    "DSH_ONEBOT_TOKEN", "ONEBOT_TOKEN", "DSH_NAPCAT_TOKEN",
    "DSH_OFM_KEY", "DSH_SING_OWNER", "DSH_SELF_ID",
    "DSH_MEMORY_KEY", "DSH_WEB_KEY", "DSH_VIDEO_KEY",
    "DSH_TTS_KEY", "DSH_VOICE_KEY",
)

lines_out = []
n_keys = 0
for raw in open(src, encoding="utf-8").read().splitlines():
    s = raw.strip()
    if s.startswith("#") or not s:
        lines_out.append(raw)
        continue
    if "=" not in s:
        lines_out.append(raw)
        continue
    k, v = s.split("=", 1)
    k = k.strip()
    is_sensitive = any(k.startswith(p) or p in k for p in SENSITIVE_PREFIX)
    if is_sensitive and v.strip():
        n_keys += 1
        lines_out.append(f"{k}=<在此填入你的值>")
    else:
        lines_out.append(raw)

content = "\n".join(lines_out) + "\n"
header = (
    "# ═══════════════════════════════════════════════════════════\n"
    "# robot.env 模板（脱敏版）\n"
    "#\n"
    "# 本文件由 robot.env 自动生成，所有密钥值已替换为占位符。\n"
    "# 复制成 robot.env 后逐项填值：\n"
    "#   cp robot.env.example robot.env && chmod 600 robot.env\n"
    "#\n"
    "# 注意：robot.env 已被 .gitignore 排除，真实密钥不要提交。\n"
    "# ═══════════════════════════════════════════════════════════\n\n"
)
open(dst, "w", encoding="utf-8").write(header + content)
print(f"  生成 {dst}")
print(f"  脱敏 {n_keys} 处密钥")
print(f"  总行数 {len(lines_out)}")

# 验证没有残留真值
import subprocess
check = subprocess.run(
    ["grep", "-cE", "sk-[A-Za-z0-9]{10}|[a-f0-9]{32}\\.", dst],
    capture_output=True, text=True)
print(f"  残留疑似密钥: {check.stdout.strip() or 0} 行")
