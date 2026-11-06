# -*- coding: utf-8 -*-
"""补丁 12：翻译走独立的、便宜的、非推理模型。

实测（2026-10-19）：
  用 self.context.llm_generate() 翻译时，
  默认 provider 是 buddy/hy3 —— 这是个**推理模型**，
  max_tokens 不够时全部消耗在思考上，返回
  finish_reason=length、content=null。
  表现就是「翻译静默失败，退回中文，然后画出云」。

  实测能正常出翻译的：
      buddy/deepseek-v4.1-flash  ✓
      buddy/glm-5.3-flash        ✓
      buddy/minimax-m3           ✓
      buddy/hy3 / hy3-x / kimi-k3-1 / deepseek-v4-pro  ✗ (length, 空)

  所以翻译要指定模型 + 给足 token。

注意：llm_generate 的 chat_provider_id 用的是 AstrBot 的 provider id
（形如 openai/buddy/deepseek-v4.1-flash），不是裸 model 名。
"""
import sys

P = '/AstrBot/data/plugins/dsh-imagegen/main.py'
src = open(P, encoding='utf-8').read()
orig = src

# ---------- 1. 配置项 ----------
OLD_CFG = '''BACKEND = os.environ.get("DSH_IMG_BACKEND", "openai").strip().lower()'''
NEW_CFG = '''# 翻译用的 provider（AstrBot provider id）。留空则用默认 provider。
# 必须选**非推理**模型：推理模型在小 max_tokens 下会把额度全花在思考上，
# 返回 content=null（buddy/hy3 实测如此）。
TRANSLATE_PROVIDER = os.environ.get(
    "DSH_IMG_TR_PROVIDER", "openai/buddy/deepseek-v4.1-flash"
).strip()
TRANSLATE_TOKENS = int(os.environ.get("DSH_IMG_TR_TOKENS", "300"))

BACKEND = os.environ.get("DSH_IMG_BACKEND", "openai").strip().lower()'''
if OLD_CFG not in src:
    print('MISS CFG'); sys.exit(1)
src = src.replace(OLD_CFG, NEW_CFG, 1)

# ---------- 2. 翻译调用指定 provider + token ----------
OLD_CALL = '''        resp = await asyncio.wait_for(
            ctx.llm_generate(
                prompt=(
                    "把下面这句中文画图描述翻译成英文提示词。"
                    "只输出英文，不要解释、不要引号、不要加任何风格词。"
                    "保留主体、数量、颜色、动作、场景。\\n"
                    "中文：%s\\n英文：" % p
                )
            ),
            timeout=20,
        )'''
NEW_CALL = '''        kwargs = {
            "prompt": (
                "把下面这句中文画图描述翻译成英文提示词。"
                "只输出英文，不要解释、不要引号、不要加任何风格词。"
                "保留主体、数量、颜色、动作、场景。\\n"
                "中文：%s\\n英文：" % p
            ),
            # 给足 token：推理模型在小额度下会把 content 吃光
            "max_tokens": TRANSLATE_TOKENS,
        }
        if TRANSLATE_PROVIDER:
            kwargs["chat_provider_id"] = TRANSLATE_PROVIDER
        resp = await asyncio.wait_for(ctx.llm_generate(**kwargs), timeout=25)'''
if OLD_CALL not in src:
    print('MISS CALL'); sys.exit(1)
src = src.replace(OLD_CALL, NEW_CALL, 1)

open(P, 'w', encoding='utf-8').write(src)
import ast
ast.parse(src)
print('patch12 OK: %d -> %d' % (len(orig), len(src)))
