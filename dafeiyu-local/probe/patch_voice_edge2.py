import re, sys, ast

# 容器内路径
P = "/AstrBot/data/plugins/dsh-voice/main.py"
src = open(P, encoding="utf-8").read()

old_head = '''async def _synthesize(text: str, ref: str) -> tuple[str | None, str]:
    """合成语音，返回 (文件路径, 错误)；服务失败后才走 Edge。"""
    if not API_KEY:
        return None, "未配置 DSH_VOICE_API_KEY"
    if not _valid_ref(ref):
        kind = "UUID" if BACKEND == "wusound" else "32 位十六进制"
        return None, f"音色 ID 非法（需 {kind}）：{ref!r}"

    os.makedirs(TMP_DIR, exist_ok=True)
    last_err = ""
    async with _sem:
        async with aiohttp.ClientSession() as session:'''

new_head = '''async def _synthesize(text: str, ref: str) -> tuple[str | None, str]:
    """合成语音，返回 (文件路径, 错误)；服务失败后才走 Edge。

    BACKEND=edge 时完全跳过 Fish/悟声主链（不需要 API_KEY 与 reference_id），
    直接使用 Edge ReadAloud，避免被 _valid_ref / API_KEY 前置校验挡掉。
    """
    os.makedirs(TMP_DIR, exist_ok=True)

    if BACKEND == "edge":
        t0 = time.time()
        audio, err = await _edge_tts_once(text)
        if audio:
            path = os.path.join(TMP_DIR, f"tts_{int(time.time() * 1000)}.mp3")
            with open(path, "wb") as f:
                f.write(audio)
            logger.info(
                "[voice] Edge 合成成功 voice=%s %d字 %dB %.1fs -> %s",
                EDGE_VOICE, len(text), len(audio), time.time() - t0, path,
            )
            return path, ""
        logger.warning("[voice] Edge 合成失败：%s", err)
        return None, err or "Edge 合成失败"

    if not API_KEY:
        return None, "未配置 DSH_VOICE_API_KEY（若只想用 Edge，请设 DSH_VOICE_BACKEND=edge）"
    if not _valid_ref(ref):
        kind = "UUID" if BACKEND == "wusound" else "32 位十六进制"
        return None, f"音色 ID 非法（需 {kind}）：{ref!r}"

    last_err = ""
    async with _sem:
        async with aiohttp.ClientSession() as session:'''

if old_head in src:
    src = src.replace(old_head, new_head, 1)
    print("[patch1] _synthesize edge 直通 OK")
else:
    print("[patch1] FAIL: 未匹配到原函数头")
    sys.exit(1)

try:
    ast.parse(src)
    print("[check] ast.parse OK")
except SyntaxError as e:
    print("[check] SyntaxError:", e)
    sys.exit(1)

open(P, "w", encoding="utf-8").write(src)
print("[write] 已写回")
