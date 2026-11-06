# -*- coding: utf-8 -*-
"""补丁 13：翻译层可关闭（原生中文模型不需要翻译）。

背景（2026-10-19）：
  翻译层最初是给 Pollinations/Flux 用的 —— 那批模型对中文理解极差，
  「一只圆滚滚的蓝白色胖鲸鱼」直译进去会画成一团云，必须先翻成英文。

  切到智谱 CogView-4 后情况变了：它原生支持中文提示词，
  翻成英文反而丢了细节（"round chubby blue and white whale"
  丢掉了「可爱」「大鲸鱼」这类修饰）。

  代价也真实存在：每次画图多一次 LLM 调用 + 2~4 秒延迟。

  所以做成开关：
    DSH_IMG_TR_PROVIDER=openai/xxx   → 翻译（原行为，给 Flux/SDXL 用）
    DSH_IMG_TR_PROVIDER=             → 关（原生中文模型）
  默认 auto：读后端，CogView 走中文，Pollinations 走翻译。
"""
import sys

P = '/AstrBot/data/plugins/dsh-imagegen/main.py'
src = open(P, encoding='utf-8').read()
orig = src

# ---------- 1. _to_english 开头加开关判断 ----------
OLD_HEAD = '''    p = (prompt or "").strip()
    if not p or not _CJK_RE.search(p):
        return p                      # 没有中文，不用翻
    if ctx is None:
        return p                      # 没有 LLM 可用，只能硬着头皮上'''
NEW_HEAD = '''    # 开关：置空 = 不翻译。原生中文模型（CogView）不需要这一层，
    # 翻成英文反而丢修饰词，还白搭一次 LLM 调用和几秒延迟。
    if not TRANSLATE_PROVIDER:
        return (prompt or "").strip()

    p = (prompt or "").strip()
    if not p or not _CJK_RE.search(p):
        return p                      # 没有中文，不用翻
    if ctx is None:
        return p                      # 没有 LLM 可用，只能硬着头皮上'''
if OLD_HEAD not in src:
    print('MISS HEAD'); sys.exit(1)
src = src.replace(OLD_HEAD, NEW_HEAD, 1)

# ---------- 2. 后端决定默认值（auto 模式） ----------
OLD_CFG = '''# 翻译用的 provider（AstrBot provider id）。留空则用默认 provider。
# 必须选**非推理**模型：推理模型在小 max_tokens 下会把额度全花在思考上，
# 返回 content=null（buddy/hy3 实测如此）。
TRANSLATE_PROVIDER = os.environ.get(
    "DSH_IMG_TR_PROVIDER", "openai/buddy/deepseek-v4.1-flash"
).strip()'''
NEW_CFG = '''# 翻译用的 provider（AstrBot provider id）。
#   设成具体 id  → 强制翻译（给 Flux/SDXL 这类不懂中文的模型）
#   设成 auto     → 按后端自动：原生中文模型不翻，海外模型翻（默认）
#   设成空       → 永远不翻
# 翻译用的模型必须是**非推理**模型：推理模型在小 max_tokens 下会把额度
# 全花在思考上，返回 content=null（buddy/hy3 实测如此）。
TRANSLATE_PROVIDER = os.environ.get("DSH_IMG_TR_PROVIDER", "auto").strip()

# 认得中文的模型（含这些关键词就不翻译）
_NATIVE_ZH = ("cogview", "kolors", "glm-image", "qwen-image", "ernie", "seedream")'''
if OLD_CFG not in src:
    print('MISS CFG'); sys.exit(1)
src = src.replace(OLD_CFG, NEW_CFG, 1)

# ---------- 3. BACKEND 定义之后解析 auto ----------
OLD_BE = '''BACKEND = os.environ.get("DSH_IMG_BACKEND", "openai").strip().lower()'''
NEW_BE = '''BACKEND = os.environ.get("DSH_IMG_BACKEND", "openai").strip().lower()

# auto → 具体 provider：原生中文模型关翻译，其余保持翻译
if TRANSLATE_PROVIDER.lower() == "auto":
    _mdl = (MODEL if BACKEND != "pollinations" else POLL_MODEL).lower()
    TRANSLATE_PROVIDER = "" if any(k in _mdl for k in _NATIVE_ZH) else "openai/buddy/deepseek-v4.1-flash"'''
if OLD_BE not in src:
    print('MISS BE'); sys.exit(1)
src = src.replace(OLD_BE, NEW_BE, 1)

open(P, 'w', encoding='utf-8').write(src)
import ast
ast.parse(src)
print('patch13 OK: %d -> %d' % (len(orig), len(src)))