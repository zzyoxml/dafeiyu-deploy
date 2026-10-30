import pathlib
import shutil
import time

P = pathlib.Path("/opt/dafeiyu/data/astrbot/plugins/dsh-voice/main.py")
bak = P.with_suffix(f".py.bak-liuying-{time.strftime('%H%M%S')}")
shutil.copyfile(P, bak)
print(f"  已备份 → {bak.name}")

src = P.read_text(encoding="utf-8")

# 在 _edge_tts_once 成功返回前，插入 RVC 变声步骤。
# 这样 dsh-voice 的所有语音出口（工具调用、兜底、/说话）都变成流萤音色。
OLD_MARK = '''            if proc.returncode == 0 and os.path.exists(path):
                with open(path, "rb") as f:
                    audio = f.read()
                if len(audio) > 256:
                    return audio, ""'''

NEW_MARK = '''            if proc.returncode == 0 and os.path.exists(path):
                with open(path, "rb") as f:
                    audio = f.read()
                if len(audio) > 256:
                    # 2026-10-30：用户要求「原来的语言发言也改为这个音色」。
                    # Edge 只是通用女声，必须再过 RVC 才是流萤。
                    # 变声失败就退回原声，绝不因为音色问题而完全不发声。
                    try:
                        liu = await _liuying_convert(path)
                        if liu and os.path.exists(liu):
                            with open(liu, "rb") as f:
                                audio = f.read()
                            logger.info("[voice] 已转换为流萤音色 %dB", len(audio))
                            try:
                                os.remove(liu)
                            except OSError:
                                pass
                    except Exception as exc:  # noqa: BLE001
                        logger.warning("[voice] 流萤变声失败，用原声：%s", exc)
                    return audio, ""'''

if OLD_MARK not in src:
    print("  ❌ 未找到插入点")
    raise SystemExit(1)

src = src.replace(OLD_MARK, NEW_MARK, 1)

# 插入 _liuying_convert 辅助函数（放在 _edge_tts_once 之前）
HELPER = '''async def _liuying_convert(mp3_path: str) -> str | None:
    """把 Edge 出的 mp3 过一遍 RVC，换成流萤音色，返回新 mp3 路径。

    复用 /AstrBot/data/sing 里已装好的 RVC（venv 在挂载卷上，稳定）。
    说话场景不需要 demucs 分离伴奏 —— Edge 输出本身就是干净人声，
    直接转 40k 单声道喂 cover.py，实测 20 字约 15~20 秒。
    """
    import shutil as _sh
    sing = "/AstrBot/data/sing"
    venv_py = os.path.join(sing, "venv", "bin", "python")
    cover = os.path.join(sing, "cover.py")
    model = os.path.join(sing, "model", "liuying.pth")
    if not (os.path.isfile(venv_py) and os.path.isfile(cover) and os.path.isfile(model)):
        return None

    tag = int(time.time() * 1000)
    wav_in = os.path.join(TMP_DIR, f"vly_in_{tag}.wav")
    wav_out = os.path.join(TMP_DIR, f"vly_out_{tag}.wav")
    mp3_out = os.path.join(TMP_DIR, f"vly_{tag}.mp3")

    async def _sh_run(args, timeout):
        p = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        try:
            await asyncio.wait_for(p.communicate(), timeout=timeout)
        except asyncio.TimeoutError:
            p.kill()
            raise RuntimeError("超时")
        if p.returncode != 0:
            raise RuntimeError(f"退出码 {p.returncode}")

    try:
        await _sh_run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                       "-i", mp3_path, "-ar", "40000", "-ac", "1", wav_in], 60)
        await _sh_run([venv_py, cover, wav_in, wav_out, "0", "rmvpe"], 240)
        if not os.path.exists(wav_out) or os.path.getsize(wav_out) < 1024:
            return None
        await _sh_run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                       "-i", wav_out, "-ar", "44100", "-ac", "2",
                       "-b:a", "128k", mp3_out], 60)
        return mp3_out if os.path.exists(mp3_out) else None
    finally:
        for p in (wav_in, wav_out):
            try:
                os.remove(p)
            except OSError:
                pass


async def _edge_tts_once'''

if "async def _liuying_convert" not in src:
    src = src.replace("async def _edge_tts_once", HELPER, 1)
    print("  ✅ 已插入 _liuying_convert")
else:
    print("  ⚠ _liuying_convert 已存在，跳过")

P.write_text(src, encoding="utf-8")
print(f"  ✅ 写入完成，{len(src)} 字符")

import ast
ast.parse(P.read_text(encoding="utf-8"))
print("  ✅ 语法 OK")
