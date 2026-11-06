# -*- coding: utf-8 -*-
"""补丁 11：生图前把中文提示词翻成英文。

实测（2026-10-19）：
  "a cute chubby whale chibi anime"      → 正确的胖鲸鱼 ✓
  "一只圆滚滚的蓝白色胖鲸鱼"              → 一团云 ✗
  "一只圆滚滚的蓝白色胖鲸鱼, cute chibi"   → 动漫少女 ✗

Flux 系列对中文理解很弱，中文 prompt 出来的经常是模糊意象。
但用户在群里说的是中文，不能要求他们说英文。

解法：_generate() 入口处先用轻量 LLM 把 prompt 转成英文再交给生图。
  · 已经是英文的（全 ASCII）直接跳过，省一次调用
  · 转换失败就退回原文（不能因为翻译挂了就不画）
  · 只转主体描述，风格串在 _request_* 里另外拼，不参与翻译
"""
import sys

P = '/AstrBot/data/plugins/dsh-imagegen/main.py'
src = open(P, encoding='utf-8').read()
orig = src

# ---------- 1. 新增翻译函数（放在 _generate 之前） ----------
ANCHOR = 'async def _generate(prompt: str):'
HELPER = '''_CJK_RE = __import__("re").compile(r"[\\u4e00-\\u9fff]")


async def _to_english(prompt: str, ctx=None) -> str:
    """把中文画图描述转成英文。失败或本来就是英文时原样返回。

    为什么要这一步：Flux / SDXL 这类模型对中文支持很差。
    实测同样一句「一只圆滚滚的蓝白色胖鲸鱼」，
    中文直接喂进去出来是一团云，翻成英文就是正确的鲸鱼。
    """
    p = (prompt or "").strip()
    if not p or not _CJK_RE.search(p):
        return p                      # 没有中文，不用翻
    if ctx is None:
        return p                      # 没有 LLM 可用，只能硬着头皮上
    try:
        resp = await asyncio.wait_for(
            ctx.llm_generate(
                prompt=(
                    "把下面这句中文画图描述翻译成英文提示词。"
                    "只输出英文，不要解释、不要引号、不要加任何风格词。"
                    "保留主体、数量、颜色、动作、场景。\\n"
                    "中文：%s\\n英文：" % p
                )
            ),
            timeout=20,
        )
        en = (
            getattr(resp, "completion_text", None)
            or getattr(resp, "_completion_text", None)
            or ""
        ).strip()
        en = en.strip('"\\'` \\n')
        # 翻译结果至少要像英文：有 ASCII 字母、没有大片中文
        if en and not _CJK_RE.search(en) and len(en) >= 3:
            logger.info("[imagegen] 提示词译为英文：%s -> %s", p[:40], en[:80])
            return en
        logger.warning("[imagegen] 翻译结果不可用，用原文：%r", en[:60])
    except BaseException as exc:
        logger.warning("[imagegen] 翻译失败（用原文继续）：%s", exc)
    return p


''' + ANCHOR
if ANCHOR not in src:
    print('MISS ANCHOR'); sys.exit(1)
src = src.replace(ANCHOR, HELPER, 1)

# ---------- 2. _generate 增加 ctx 参数并在入口翻译 ----------
OLD_SIG = '''async def _generate(prompt: str):
    """按主模型 + 备用模型顺序尝试生图。返回 (path, err)。"""'''
NEW_SIG = '''async def _generate(prompt: str, ctx=None):
    """按主模型 + 备用模型顺序尝试生图。返回 (path, err)。

    ctx 是 AstrBot 的 Context，用来把中文描述翻成英文；
    不传就跳过翻译（保持旧行为，测试脚本仍可直接调用）。
    """'''
if OLD_SIG not in src:
    print('MISS SIG'); sys.exit(1)
src = src.replace(OLD_SIG, NEW_SIG, 1)

OLD_GATE = '''    # pollinations 免 key，只要不是 openai 后端就不拦
    if BACKEND == "openai" and not API_KEY:'''
NEW_GATE = '''    # 中文描述先转英文 —— Flux/SDXL 对中文理解很差，
    # 「胖鲸鱼」直译进去会画成云，翻成 "chubby whale" 才对。
    prompt = await _to_english(prompt, ctx)

    # pollinations 免 key，只要不是 openai 后端就不拦
    if BACKEND == "openai" and not API_KEY:'''
if OLD_GATE not in src:
    print('MISS GATE'); sys.exit(1)
src = src.replace(OLD_GATE, NEW_GATE, 1)

# ---------- 3. 所有调用点传 ctx ----------
calls = src.count('await _generate(')
src = src.replace('await _generate(', 'await _generate(')
# 用正则给每个调用补 self.context（仅限 self.context 可用处）
import re
src2, n = re.subn(
    r'await _generate\(([^,)]+)\)',
    r'await _generate(\1, getattr(self, "context", None))',
    src,
)
src2, n2 = re.subn(
    r'await _generate\(([^,]+),\s*([^,)]+)\)(?!\s*,)',
    r'await _generate(\1, \2, getattr(self, "context", None))',
    src2,
)
src = src2
print('  调用点补 ctx: %d + %d' % (n, n2))

open(P, 'w', encoding='utf-8').write(src)
import ast
ast.parse(src)
print('patch11 OK: %d -> %d 字节' % (len(orig), len(src)))
