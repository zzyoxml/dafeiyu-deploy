"""AstrBot 插件：流萤音色语音（接管 dsh-voice 的语音出口）

背景与设计决策（都基于本机实测，不是猜的）：
  1. Edge TTS 7.2.7 起对 speech.platform.bing.com 返回 403（Sec-MS-GEC
     版本过期），升到 7.3.1 后恢复。这是语音之前一直发不出的真因。
  2. 用户要求「原来的语言发言也改为这个音色」：Edge 只提供通用女声
     （XiaoxiaoNeural），要变成流萤必须再过一道 RVC。实测链路
     Edge(40k) → cover.py → 输出，20 字 4.4 秒音频耗时约 60-90 秒 CPU。
  3. 用户要求「普通回复 20% 比例用语音」。CPU 变声慢，所以：
     - 只对短文本开口（默认 ≤ 40 字），长段落仍走文字，避免让群等 2 分钟
     - 有冷却与小时配额，防止连发
     - 概率默认 0.20，可用 DSH_VOICE_LY_RATE 调
  4. 语音必须单独 event.send 一条，不能塞 result_chain（AstrBot 混排会丢语音，
     dsh-voice / dsh-sticker / dsh-imagegen 都已验证过）。

与 dsh-voice 的关系：两条独立出口，互不干扰。
  - dsh-voice 保留（Fish/悟声 + 显式「说话」命令）
  - 本插件负责「普通回复按概率自动出声」+ 统一的流萤音色
  - 环境变量 DSH_VOICE_LY_DISABLE_DEFAULT=1 可让本插件接管默认语音
"""

import asyncio
import hashlib
import os
import random
import re
import shutil
import time
from pathlib import Path

from astrbot.api import star
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.message_components import Record
from astrbot.core import logger
from astrbot.core.message.message_event_result import MessageChain

# ---------------------------------------------------------------- 配置
SING_DIR = Path(os.environ.get("DSH_SING_DIR", "/AstrBot/data/sing"))
VENV_PY = SING_DIR / "venv" / "bin" / "python"
COVER_SCRIPT = SING_DIR / "cover.py"
VOICE_MODEL = SING_DIR / "model" / "liuying.pth"

VOICE_DIR = Path(os.environ.get("DSH_SING_VOICE_DIR", "/AstrBot/data/audio"))
CACHE_DIR = VOICE_DIR / "voice-cache"

# 概率与门槛
AUTO_RATE = float(os.environ.get("DSH_VOICE_LY_RATE", "0.20"))     # 20%
MAX_CHARS = int(os.environ.get("DSH_VOICE_LY_MAX_CHARS", "40"))    # 太长不念
COOLDOWN = int(os.environ.get("DSH_VOICE_LY_COOLDOWN", "45"))      # 全局冷却秒
HOURLY_CAP = int(os.environ.get("DSH_VOICE_LY_HOURLY", "8"))       # 每小时上限
TIMEOUT = int(os.environ.get("DSH_VOICE_LY_TIMEOUT", "300"))       # 单次变声超时

EDGE_VOICE = os.environ.get("DSH_VOICE_LY_EDGE_VOICE", "zh-CN-XiaoxiaoNeural")
EDGE_RATE = os.environ.get("DSH_VOICE_LY_EDGE_RATE", "-5%")
EDGE_PITCH = os.environ.get("DSH_VOICE_LY_EDGE_PITCH", "+2Hz")

# 主人白名单（命令优先）
OWNER_ID = os.environ.get("DSH_SING_OWNER", "").strip()

_STATE = {
    "last": 0.0,          # 上次发声时间
    "hour_win": 0.0,      # 小时窗口起点
    "hour_count": 0,      # 本小时次数
    "lock": None,         # 变声串行锁（CPU 只有 4 核）
    "cache": {},          # text_hash -> Path
}


def _norm(text: str) -> str:
    """归一化文本用于缓存键（去空白、标点差异、emoji）。"""
    t = re.sub(r"[`*_#>\[\]()]", "", str(text or ""))
    t = re.sub(r"\s+", "", t)
    return t.strip()


def _keep_for_voice(text: str) -> bool:
    """这句适不适合念：太短没意思、太长太慢、纯符号/纯表情不念。"""
    t = _norm(text)
    if len(t) < 4 or len(t) > MAX_CHARS:
        return False
    # 没有任何中文/英文时不念（纯 emoji / 纯表情）
    if not re.search(r"[\u4e00-\u9fffA-Za-z0-9]", t):
        return False
    # 命令回执、自检表格类不念
    if re.match(r"^(/|🎤|🔍|🎵|⏳|💤|✅|❌|🎶|📊)", t):
        return False
    if "自检" in t or "缓存：" in t:
        return False
    return True


def _allow_now() -> bool:
    """冷却 + 小时配额。返回 True 表示可以发声。"""
    now = time.time()
    if now - _STATE["last"] < COOLDOWN:
        return False
    if now - _STATE["hour_win"] > 3600:
        _STATE["hour_win"] = now
        _STATE["hour_count"] = 0
    if _STATE["hour_count"] >= HOURLY_CAP:
        return False
    return True


def _mark_used():
    _STATE["last"] = time.time()
    _STATE["hour_count"] += 1


def _voice_lock() -> asyncio.Lock:
    if _STATE["lock"] is None:
        _STATE["lock"] = asyncio.Lock()
    return _STATE["lock"]


async def _run(cmd: list, timeout: int = 120) -> str:
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        out, err = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        raise RuntimeError(f"{Path(cmd[0]).name} 超时")
    if proc.returncode != 0:
        detail = (err or b"").decode("utf-8", "ignore").strip().splitlines()
        tail = " | ".join(detail[-3:]) if detail else ""
        raise RuntimeError(f"{Path(cmd[0]).name} 失败{('：' + tail) if tail else ''}")
    return (out or b"").decode("utf-8", "ignore")


async def _edge_tts(out_path: str, text: str) -> bool:
    """Edge 合成：优先用 venv 的 python（那里是 7.3.1），失败再试本进程。

    为什么不能直接 import：主环境是镜像自带的 7.2.7，对
    speech.platform.bing.com 恒定返回 403；而 venv 在挂载卷上，
    重装容器也不会被冲掉，里面是能用的 7.3.1。
    """
    script = (
        "import asyncio,sys\n"
        "import edge_tts\n"
        "async def m():\n"
        "    await edge_tts.Communicate(sys.argv[2], sys.argv[3],\n"
        "        rate=sys.argv[4], pitch=sys.argv[5]).save(sys.argv[1])\n"
        "asyncio.run(m())\n"
    )
    # ① venv
    if VENV_PY.exists():
        try:
            sp = Path("/tmp") / f"_edge_{int(time.time()*1000)}.py"
            sp.write_text(script, encoding="utf-8")
            try:
                await _run(
                    [str(VENV_PY), str(sp), out_path, text,
                     EDGE_VOICE, EDGE_RATE, EDGE_PITCH],
                    timeout=120,
                )
            finally:
                sp.unlink(missing_ok=True)
            if Path(out_path).exists() and Path(out_path).stat().st_size > 512:
                logger.info("[voice-ly] Edge 合成（venv）成功")
                return True
        except Exception as exc:
            logger.warning("[voice-ly] venv Edge 失败，回退主环境：%s",
                           str(exc)[:100])

    # ② 本进程（镜像自带的旧版，通常 403，留作兜底）
    try:
        import edge_tts
        await edge_tts.Communicate(
            text, EDGE_VOICE, rate=EDGE_RATE, pitch=EDGE_PITCH
        ).save(out_path)
        if Path(out_path).exists() and Path(out_path).stat().st_size > 512:
            logger.info("[voice-ly] Edge 合成（主环境）成功")
            return True
    except Exception as exc:
        logger.warning("[voice-ly] 主环境 Edge 也失败：%s", str(exc)[:100])
    return False


async def _synthesize_liuying(text: str) -> Path | None:
    """Edge 合成 → RVC 变流萤音色 → mp3。带磁盘缓存（同句复用）。"""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    key = hashlib.md5(
        (_norm(text) + EDGE_VOICE + EDGE_RATE + EDGE_PITCH).encode("utf-8")
    ).hexdigest()[:16]
    cached = CACHE_DIR / f"{key}.mp3"
    if cached.exists() and cached.stat().st_size > 1024:
        return cached

    tmp = CACHE_DIR / f".{key}-{int(time.time()*1000)}"
    raw_mp3 = Path(f"{tmp}-raw.mp3")
    raw_wav = Path(f"{tmp}-raw.wav")
    out_wav = Path(f"{tmp}-ai.wav")

    try:
        # Edge 合成必须走 venv 的 python，不能用本进程的 import：
        # 实测主环境是镜像自带的 edge-tts 7.2.7，对 speech.platform.bing.com
        # 恒定返回 403（Sec-MS-GEC 版本过期）；7.3.1 才能合成。
        # 而 sing/venv 在 /AstrBot/data 挂载卷上，不受 --force-recreate 影响，
        # 里面已经装好 7.3.1。所以用 _edge_tts()：优先 venv，失败再回退本进程。
        if not await _edge_tts(str(raw_mp3), text):
            raise RuntimeError("Edge TTS 合成失败（venv 与主环境都不可用）")
        if not raw_mp3.exists() or raw_mp3.stat().st_size < 512:
            raise RuntimeError("Edge 合成产物为空")

        # RVC 期望 40k 单声道
        await _run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-i", str(raw_mp3), "-ar", "40000", "-ac", "1", str(raw_wav)],
            timeout=60,
        )
        await _run(
            [str(VENV_PY), str(COVER_SCRIPT), str(raw_wav), str(out_wav), "0", "rmvpe"],
            timeout=TIMEOUT,
        )
        if not out_wav.exists() or out_wav.stat().st_size < 1024:
            raise RuntimeError("RVC 输出为空")

        await _run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
             "-i", str(out_wav), "-ar", "44100", "-ac", "2",
             "-b:a", "128k", str(cached)],
            timeout=60,
        )
        return cached if cached.exists() else None
    except Exception as exc:
        logger.warning("[voice-ly] 合成失败：%s", exc)
        return None
    finally:
        for p in (raw_mp3, raw_wav, out_wav):
            try:
                p.unlink(missing_ok=True)
            except Exception:
                pass


async def _readiness() -> dict:
    r = {
        "venv": VENV_PY.exists(),
        "cover": COVER_SCRIPT.exists(),
        "model": VOICE_MODEL.exists(),
        "ffmpeg": shutil.which("ffmpeg") is not None,
        "edge": False,
    }
    # edge-tts 的检测必须在「插件所在的主环境」里 import：
    # 实测用 venv 的 python 去 import 会因为 venv 里没装而误报 ❌，
    # 但实际合成是在本进程（主环境）里跑的，主环境有 7.3.1 就够了。
    try:
        import edge_tts  # noqa: F401
        r["edge"] = True
        r["edge_version"] = getattr(edge_tts, "__version__", "?")
    except Exception as exc:
        r["edge"] = False
        r["edge_err"] = str(exc)[:80]
    return r


# ---------------------------------------------------------------- 插件
class VoiceLiuyingPlugin(star.Star):
    """普通回复按概率用流萤音色说话"""

    def __init__(self, context, config=None):
        super().__init__(context, config)
        logger.info(
            "[voice-ly] 已加载：概率=%.0f%% 最短4字/最长%d字 冷却%ds 小时上限%d "
            "音色=%s",
            AUTO_RATE * 100, MAX_CHARS, COOLDOWN, HOURLY_CAP, EDGE_VOICE,
        )

    # -------- /流萤语音状态 --------
    @filter.regex(r"^\s*(?:@\S+\s*)?/?(?:流萤语音状态|语音状态)\s*$")
    async def cmd_status(self, event: AstrMessageEvent):
        """检查流萤语音链路 + 概率配置"""
        r = await _readiness()
        lines = ["🔊 流萤语音自检"]
        for k, label in (("venv", "Python venv"), ("edge", "edge-tts"),
                         ("cover", "cover.py"), ("model", "流萤模型"),
                         ("ffmpeg", "ffmpeg")):
            lines.append(f"{'✅' if r[k] else '❌'} {label}")
        ok = all(r.values())
        lines.append("")
        lines.append("✅ 就绪：普通回复按概率自动出声" if ok else "❌ 未就绪")
        lines.append(
            f"概率 {AUTO_RATE*100:.0f}%｜4~{MAX_CHARS}字｜冷却 {COOLDOWN}s｜"
            f"小时上限 {HOURLY_CAP}"
        )
        left = max(0, HOURLY_CAP - _STATE["hour_count"])
        cd = max(0, int(COOLDOWN - (time.time() - _STATE["last"])))
        lines.append(f"本小时已用 {_STATE['hour_count']}/{HOURLY_CAP}，"
                     f"剩余 {left}；距下次可发 {cd}s")
        # 缓存
        try:
            n = len(list(CACHE_DIR.glob("*.mp3")))
            sz = sum(f.stat().st_size for f in CACHE_DIR.glob("*.mp3"))
            lines.append(f"语音缓存 {n} 句，{sz//1048576}MB")
        except Exception:
            pass
        event.set_result(event.plain_result("\n".join(lines)))

    # -------- 显式命令：/流萤说 --------
    @filter.regex(r"^\s*(?:@\S+\s*)?/?(?:流萤说|念|朗读)\s+(.+)")
    async def cmd_say(self, event: AstrMessageEvent):
        """/流萤说 <文字> —— 强制用流萤音色念出来"""
        m = re.match(r"^\s*(?:@\S+\s*)?/?(?:流萤说|念|朗读)\s+(.+)", event.message_str or "", re.S)
        text = (m.group(1) if m else "").strip()
        if not text:
            event.set_result(event.plain_result("用法：/流萤说 你好呀"))
            return
        text = text[:200]
        r = await _readiness()
        if not all(r.values()):
            miss = [k for k, v in r.items() if not v]
            event.set_result(event.plain_result(f"语音未就绪，缺：{', '.join(miss)}"))
            return
        await event.send(event.plain_result("🎙 正在用流萤声音念…"))
        lock = _voice_lock()
        async with lock:
            path = await _synthesize_liuying(text)
        if not path:
            await event.send(event.plain_result("这次没合成出来，稍后再试"))
            return
        try:
            await event.send(MessageChain(chain=[Record.fromFileSystem(str(path))]))
            _mark_used()
        except BaseException as exc:
            detail = str(exc).strip().replace("\n", " ")[:100]
            logger.warning("[voice-ly] 发送失败：%s", detail)
            await event.send(event.plain_result(f"念好了但没发出去（{detail}）"))

    # -------- 普通回复按概率出声 --------
    # 用 on_llm_response 而不是 on_decorating_result：
    #   dsh-voice 走的就是这条路径（它注释里写明「语音必须单独 event.send 一条，
    #   不能塞进 result_chain，否则 completion_text 派生会丢掉语音」）。
    #   on_decorating_result 阶段拿 result chain 再反手发第二条消息，容易和
    #   respond.stage 的发送顺序打架；on_llm_response 在结果成形时就拿到文本，
    #   可以在把文字发出去之后立刻补一条语音，时序最稳。
    @filter.on_llm_response()
    async def maybe_speak(self, event: AstrMessageEvent, response) -> None:
        """按 20% 概率给普通文字回复追加一条流萤语音"""
        try:
            if AUTO_RATE <= 0:
                return
            # 命令类回复不念（避免把自检表/歌单念出来）
            msg = (event.message_str or "")
            if re.match(r"^\s*(?:@\S+\s*)?/", msg):
                return
            if not _allow_now():
                return

            text = (getattr(response, "completion_text", "") or "").strip()
            if not text or not _keep_for_voice(text):
                return

            # 概率闸
            if random.random() >= AUTO_RATE:
                return

            r = await _readiness()
            if not all(r.values()):
                logger.warning("[voice-ly] 环境未就绪，跳过本次发声")
                return

            lock = _voice_lock()
            if lock.locked():
                # 正在变声，本轮不排队（避免让回复卡住）
                return
            async with lock:
                path = await _synthesize_liuying(text[:MAX_CHARS])
            if not path:
                return

            await event.send(MessageChain(chain=[Record.fromFileSystem(str(path))]))
            _mark_used()
            logger.info("[voice-ly] 已附语音：%s", text[:30])
        except BaseException as exc:
            # fail-open：语音是加分项，任何异常都不能影响文字回复
            logger.warning("[voice-ly] 附语音失败（不影响文字）：%s",
                           str(exc).strip().replace("\n", " ")[:120])
