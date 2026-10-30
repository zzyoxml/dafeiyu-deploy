# -*- coding: utf-8 -*-
"""补丁 10：给 dsh-imagegen 增加 Pollinations 后端（免 key）。

背景（2026-10-19 实测）：
  用户的 buddy 网关有 111 个对话模型，但**没有任何生图路由**
  （POST /v1/images/generations → 404）。三个 key 在智谱/硅基流动/agnes
  全部 401。所以「没有生图 key」不是配置问题，是上游没这个能力。

  Pollinations 是唯一可用的免 key 通道：
      GET https://image.pollinations.ai/prompt/<urlencoded>?width=..&model=..
      返回原始图片字节（不是 JSON）
  实测 2026-10-19 08:34 出图成功（45KB JPEG，768x768）。

  但它有坑：免费额度按**出口 IP** 计（1 张/45 秒），共享 VPN 出口
  可能被刷爆，此时返回 HTTP 402 + JSON {"error":{"code":"FREE_LIMIT"}}。
  所以必须把 402 单独识别出来，回一句人话，而不是当成普通失败。

改动：
  1. 新增 DSH_IMG_BACKEND 开关（openai=原逻辑 / pollinations=免 key）
  2. Pollinations 后端不要求 API_KEY
  3. 新增 _request_pollinations()，只走 GET，418/402 分类处理
  4. 失败回话区分「被限速」和「真失败」
"""
import sys

P = '/AstrBot/data/plugins/dsh-imagegen/main.py'
src = open(P, encoding='utf-8').read()
orig = src

# ---------- 1. 配置项 ----------
OLD_CFG = '''API_BASE = os.environ.get("DSH_IMG_API_BASE", "https://apihub.agnes-ai.com/v1")'''
NEW_CFG = '''# 后端选择：
#   openai（默认）—— 标准 POST /images/generations，需要 key
#   pollinations  —— 免 key，GET 取图；按出口 IP 限速 1 张/45 秒
BACKEND = os.environ.get("DSH_IMG_BACKEND", "openai").strip().lower()
POLL_BASE = os.environ.get(
    "DSH_IMG_POLL_BASE", "https://image.pollinations.ai/prompt"
)
POLL_MODEL = os.environ.get("DSH_IMG_POLL_MODEL", "flux")
POLL_NOLOGO = os.environ.get("DSH_IMG_POLL_NOLOGO", "1") not in ("0", "false", "False")

API_BASE = os.environ.get("DSH_IMG_API_BASE", "https://apihub.agnes-ai.com/v1")'''
if OLD_CFG not in src:
    print('MISS CFG'); sys.exit(1)
src = src.replace(OLD_CFG, NEW_CFG, 1)

# ---------- 2. 新增 pollinations 请求函数 ----------
ANCHOR = 'async def _request_once(session: aiohttp.ClientSession, model: str, prompt: str):'
NEW_FUNC = '''async def _request_pollinations(session: aiohttp.ClientSession, prompt: str):
    """Pollinations 免 key 出图。返回 (本地路径, 错误码/文案)。

    ⚠ 与 OpenAI 格式完全不同：
       · 是 GET，prompt 编进 URL 路径
       · 直接返回图片字节，不是 {"data":[{"url":...}]}
       · 限速时返回 HTTP 402 + JSON {"error":{"code":"FREE_LIMIT"}}

    402 必须单独识别 —— 这是「额度被刷完了，等会儿再来」，
    不是「画不出来」。混在一起会让群友以为机器人坏了。
    """
    import urllib.parse as _up

    full_prompt = f"{prompt.strip()}, {STYLE_SUFFIX}" if STYLE_SUFFIX else prompt.strip()
    try:
        w, h = (int(x) for x in SIZE.lower().split("x"))
    except BaseException:
        w = h = 1024
    q = {
        "width": str(w),
        "height": str(h),
        "model": POLL_MODEL,
        "seed": str(random.randint(1, 2**31 - 1)),
    }
    if POLL_NOLOGO:
        q["nologo"] = "true"
    url = "%s/%s?%s" % (
        POLL_BASE.rstrip("/"),
        _up.quote(full_prompt, safe=""),
        _up.urlencode(q),
    )

    async with session.get(url) as resp:
        raw = await resp.read()
        ctype = (resp.headers.get("Content-Type") or "").lower()
        if resp.status == 200 and raw and ("image" in ctype or raw[:3] in (b"\\xff\\xd8\\xff", b"GIF")):
            os.makedirs(SAVE_DIR, exist_ok=True)
            _sweep_old_images()
            ext = ".jpg" if raw[:3] == b"\\xff\\xd8\\xff" else ".png"
            path = os.path.join(SAVE_DIR, "img_%d%s" % (int(time.time() * 1000), ext))
            with open(path, "wb") as f:
                f.write(raw)
            return path, None
        if resp.status == 402 or b"FREE_LIMIT" in raw[:400]:
            return None, "RATE_LIMIT"
        return None, "HTTP %d: %s" % (resp.status, raw[:200].decode("utf-8", "ignore"))


''' + ANCHOR
if ANCHOR not in src:
    print('MISS ANCHOR'); sys.exit(1)
src = src.replace(ANCHOR, NEW_FUNC, 1)

# ---------- 3. _generate 支持 pollinations 且不强制 key ----------
OLD_GEN = '''    if not API_KEY:
        return None, "NO_KEY"

    models = [MODEL] + [m for m in FALLBACK_MODELS if m != MODEL]
    errors = []
    timeout = aiohttp.ClientTimeout(total=TIMEOUT)
    async with _sem:
        async with aiohttp.ClientSession(timeout=timeout) as session:
            for model in models:'''
NEW_GEN = '''    # pollinations 免 key，只要不是 openai 后端就不拦
    if BACKEND == "openai" and not API_KEY:
        return None, "NO_KEY"

    models = [MODEL] + [m for m in FALLBACK_MODELS if m != MODEL]
    errors = []
    timeout = aiohttp.ClientTimeout(total=TIMEOUT)
    async with _sem:
        async with aiohttp.ClientSession(timeout=timeout) as session:
            if BACKEND == "pollinations":
                # 免费额度按出口 IP 算（1 张/45 秒），重试间隔要够；
                # 同一 prompt 换 model 也是同一个 IP 额度，所以只试两轮。
                for attempt in range(2):
                    try:
                        path, err = await _request_pollinations(session, prompt)
                    except Exception as e:
                        path, err = None, "请求异常: %s" % e
                    if path:
                        return path, None
                    errors.append("pollinations -> %s" % err)
                    if err == "RATE_LIMIT":
                        logger.warning("[imagegen] Pollinations 免费额度用尽（%s）", err)
                        if attempt == 0:
                            await asyncio.sleep(6)
                            continue
                        return None, "RATE_LIMIT"
                    logger.warning("[imagegen] Pollinations 失败: %s", err)
                    if attempt == 0:
                        await asyncio.sleep(3)
                return None, "；".join(errors)

            for model in models:'''
if OLD_GEN not in src:
    print('MISS GEN'); sys.exit(1)
src = src.replace(OLD_GEN, NEW_GEN, 1)

# ---------- 4. 失败回话区分限速 ----------
OLD_MSG = '''            if "NO_KEY" in str(err):'''
NEW_MSG = '''            if "RATE_LIMIT" in str(err):
                yield event.plain_result(
                    "画笔今天用得太狠，被限速了，过一会儿再让我画。"
                )
            elif "NO_KEY" in str(err):'''
if OLD_MSG not in src:
    print('MISS MSG'); sys.exit(1)
src = src.replace(OLD_MSG, NEW_MSG, 1)

open(P, 'w', encoding='utf-8').write(src)
import ast
ast.parse(src)
print('patch10 OK: %d -> %d 字节' % (len(orig), len(src)))
