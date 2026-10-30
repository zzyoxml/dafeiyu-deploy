"""AstrBot 插件：流萤音色唱歌（移植自「流萤音色语音加唱歌技能包4.0」）

原技能包是 Windows + DSH MCP 架构（mcp-sing.js 提供 3 个 MCP 工具）。
本项目是 AstrBot + Docker/Linux，因此把工具逻辑移植为聊天命令。

功能对照：
  sing_probe  -> /唱歌状态
  sing_search -> /搜歌 <歌名>
  sing_cover(mode=original) -> /原唱 <歌名>
  sing_cover(mode=ai)       -> /唱歌 <歌名>   /翻唱 <歌名>

链路（与原文档一致）：
  搜歌 → yt-dlp 下载音源 → ffmpeg 截片段 →
  [AI 模式] demucs 分离人声 → RVC 换音色 → ffmpeg 混回伴奏 →
  发 QQ 语音消息

环境（本机实测）：
  - 无可用 GPU：AMD R5 220 (Caicos) 经 DirectML 实测 device_count=0，
    张量运算崩溃 0xC0000005。故 torch/demucs 全部走 CPU。
  - venv 独立于 AstrBot 主环境：/AstrBot/data/sing/venv

设计要点：
  - 语音单独发一条消息，不塞进 result_chain（AstrBot 混排会丢语音）。
  - 音频制作成功 != 已发送成功，发送与制作分别记录。
  - RVC 失败不静默退回原唱（原文档明确要求）。
"""

import asyncio
import json
import os
import re
import shutil
import time
import uuid
from pathlib import Path

from astrbot.api import star
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.message_components import Record
from astrbot.core import logger
# MessageChain 不在 api.message_components 里（实测 ImportError），
# 真实位置是 core.message.message_event_result，与 dsh-voice 一致。
from astrbot.core.message.message_event_result import MessageChain

# ---------------------------------------------------------------- 配置
SING_DIR = Path(os.environ.get("DSH_SING_DIR", "/AstrBot/data/sing"))
WORK_DIR = SING_DIR / "work"
VOICE_DIR = Path(os.environ.get("DSH_SING_VOICE_DIR", "/AstrBot/data/audio"))
VENV_PY = SING_DIR / "venv" / "bin" / "python"
RVC_DIR = SING_DIR / "rvc_cli"
COVER_SCRIPT = SING_DIR / "cover.py"
VOICE_MODEL = SING_DIR / "model" / "liuying.pth"

YTDLP = os.environ.get("DSH_YTDLP") or shutil.which("yt-dlp") or ""
# 实测：AstrBot 主环境的 PATH 里没有 yt-dlp（它装在 sing/venv 里），
# shutil.which 返回空。这里按 venv 实际位置兜底，避免 /唱歌状态 误报 FAIL。
if not YTDLP and (SING_DIR / "venv" / "bin" / "yt-dlp").exists():
    YTDLP = str(SING_DIR / "venv" / "bin" / "yt-dlp")
FFMPEG = os.environ.get("DSH_FFMPEG") or shutil.which("ffmpeg") or ""

DEMUCS_MODEL = "htdemucs"
MAX_SECONDS = 240
DEFAULT_SECONDS = 60          # 本项目默认 60 秒（原包为 30，见说明文档差异）
SEARCH_LIMIT = 5

# ---------------------------------------------------------------- 成品缓存
# 实测过的问题：同一首《全球变冷》连点 3 次，每次都重新下载 + demucs + RVC，
# 每次都烧 5-6 分钟 CPU。命中缓存时直接复用 mp3，不再下载和变声。
# 上限 100 首，超出后按「最久未使用」淘汰（LRU）——注意不是按创建时间，
# 否则一首常点的老歌会被新歌挤掉，下次又得重做。
CACHE_DIR = SING_DIR / "song-cache"
CACHE_INDEX = CACHE_DIR / "index.json"
CACHE_MAX = int(os.environ.get("DSH_SING_CACHE_MAX", "100"))

# 点歌权限：主人永远可用；群友权限由 DSH_SING_GROUP_ACCESS 控制
#   owner   = 仅主人（最保守，原默认）
#   original= 群友可用 /原唱（不用 GPU/CPU 重活，快）
#   ai      = 群友可用 /原唱 + /唱歌（CPU 翻唱，慢，必须限流）
#   all     = 等价于 ai
OWNER_ID = os.environ.get("DSH_SING_OWNER", "").strip()
GROUP_ACCESS = os.environ.get("DSH_SING_GROUP_ACCESS", "owner").strip().lower()
# 兼容旧旋钮：置 1 等于 original
if os.environ.get("DSH_SING_GROUP_ORIGINAL", "0") == "1" and GROUP_ACCESS == "owner":
    GROUP_ACCESS = "original"

# ---------------------------------------------------------- 并发与冷却
# RVC 在 CPU 上是重活（实测 20s 片段约 158s）。不加限制时，3 个人同时点歌
# 会把 4 核吃满并让所有人的请求排到十几分钟。这里按「每人 / 每群 / 全局」
# 三层限流，主人不受限。
_BUSY = {"lock": None}             # 全局最多 1 个重活（CPU 只有 4 核）
LAST_USE = {}                      # key -> 上次完成时间戳
COOLDOWN_USER = int(os.environ.get("DSH_SING_COOLDOWN_USER", "120"))
COOLDOWN_GROUP = int(os.environ.get("DSH_SING_COOLDOWN_GROUP", "30"))
MAX_SECONDS_GROUP = int(os.environ.get("DSH_SING_MAX_SECONDS_GROUP", "30"))
QUEUE_WAIT_MAX = int(os.environ.get("DSH_SING_QUEUE_WAIT", "180"))


def _busy_lock() -> asyncio.Lock:
    """进程内全局互斥锁（懒初始化，避免在无事件循环时创建）。"""
    if _BUSY["lock"] is None:
        _BUSY["lock"] = asyncio.Lock()
    return _BUSY["lock"]

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
)

# 过滤掉伴奏/KTV/短剧类结果（原文档要求）
_BAD_WORDS = ("伴奏", "纯音乐", "KTV", "ktv", "消音", "无人声", "短剧", "合集",
              "翻唱合集", "DJ", "dj", "讲解", "reaction", "教程")


# ---------------------------------------------------------------- 工具
def _slugify(text: str) -> str:
    """标题清理：保留中英文数字，其它压成 -，限长 40。"""
    s = re.sub(r'[\\/:*?"<>|\r\n\t]+', " ", str(text or ""))
    s = re.sub(r"[^\w\u4e00-\u9fff._ -]+", " ", s)
    s = re.sub(r"\s+", "-", s).strip("-")
    return s[:40] or "song"


def _stamp() -> str:
    return time.strftime("%Y%m%d%H%M%S")


def _umo(event) -> str:
    """会话标识（群/私聊），用作「刚展示的歌单」和冷却的键。"""
    return getattr(event, "unified_msg_origin", "") or "global"


# 会话 -> 刚 /歌单 展示的那几条（供「选 1」复用，不必重新搜）
_SHOWN: dict = {}


# ---------------------------------------------------------- 进度持久化
# 容器日志随 --force-recreate 一起消失（实测把我正在跑的 demucs 打断后
# 连"卡在哪一步"都查不到）。这里把每条任务的状态写到 JSONL，独立于日志，
# 事后能复盘，/唱歌状态 也能显示当前在干什么。
STATUS_FILE = SING_DIR / "status.jsonl"
_CURRENT = {"step": "", "song": "", "since": 0.0}


def _step(name: str):
    """记录当前步骤（同时写内存与日志，便于事后排查）。"""
    _CURRENT["step"] = name
    _CURRENT["since"] = time.time()
    logger.info("[sing] 步骤：%s", name)


def _status_write(**kw):
    try:
        rec = {"ts": time.strftime("%Y-%m-%d %H:%M:%S"), **_CURRENT, **kw}
        with open(STATUS_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:
        pass


def _read_last_status():
    """读最近一条有结果的任务记录（start 不算结果）。"""
    try:
        if not STATUS_FILE.exists():
            return None
        lines = STATUS_FILE.read_text(encoding="utf-8").strip().splitlines()
        for line in reversed(lines[-50:]):
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get("event") in ("ok", "fail", "send_failed"):
                return rec
    except Exception:
        pass
    return None


# ---------------------------------------------------------------- 缓存实现
def _cache_key(song: str, mode: str, seconds: int, start: float, pitch: int,
               title: str = "") -> str:
    """缓存键 = 歌名 + 模式 + 片段参数（title 参数保留但不再参与计算）。

    2026-10-30 修正：原本把音源标题也算进键里，结果是「必须先搜歌拿到
    标题才能命中」，也就是每次点歌仍要多花 5-8 秒去联网搜索，缓存的
    提速效果打了对折；而且播种/迁移时很容易只存了一份、另一份查不到。

    改成纯语义键：同一首歌同一参数，不管当时选的是哪个音源视频，都
    认作同一份成品。这是用户要的语义 —— 「唱过的歌再点就秒发」。
    代价是换了音源版本后仍复用旧音频；这可以接受（歌名相同、参数相同，
    门口听感差异很小），而且用户真正在意的是「别再让我等 5 分钟」。
    """
    import hashlib
    raw = "\x1f".join([
        song.strip().lower(),
        mode,
        str(int(seconds)),
        str(int(start)),
        str(int(pitch)),
    ])
    return hashlib.md5(raw.encode("utf-8")).hexdigest()[:16]


def _cache_load() -> dict:
    try:
        if CACHE_INDEX.exists():
            data = json.loads(CACHE_INDEX.read_text(encoding="utf-8"))
            if isinstance(data, dict) and "entries" in data:
                return data
    except Exception as exc:
        logger.warning("[sing] 缓存索引读取失败（当作空）：%s", exc)
    return {"entries": {}}


def _cache_save(data: dict):
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        tmp = CACHE_INDEX.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
        tmp.replace(CACHE_INDEX)
    except Exception as exc:
        logger.warning("[sing] 缓存索引写入失败：%s", exc)


def _cache_get(key: str):
    """命中则返回文件路径（并刷新 last_used），否则 None。"""
    data = _cache_load()
    ent = (data.get("entries") or {}).get(key)
    if not ent:
        return None
    p = CACHE_DIR / ent.get("file", "")
    if not p.exists() or p.stat().st_size < 1024:
        # 文件被手工删了 —— 清掉这条脏索引
        data["entries"].pop(key, None)
        _cache_save(data)
        return None
    ent["last_used"] = time.time()
    ent["hits"] = int(ent.get("hits", 0)) + 1
    _cache_save(data)
    logger.info("[sing] 缓存命中：%s（第 %d 次）", ent.get("title") or key, ent["hits"])
    return p


def _cache_put(key: str, src_file: Path, song: str, mode: str, seconds: int,
               start: float, pitch: int, title: str, source: str) -> Path:
    """把成品收进缓存，超上限时按 last_used 淘汰最旧的。"""
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        dst = CACHE_DIR / f"{key}.mp3"
        shutil.copyfile(src_file, dst)
        data = _cache_load()
        entries = data.setdefault("entries", {})
        entries[key] = {
            "file": dst.name,
            "song": song,
            "mode": mode,
            "seconds": int(seconds),
            "start": int(start),
            "pitch": int(pitch),
            "title": title,
            "source": source,
            "bytes": dst.stat().st_size,
            "created": time.time(),
            "last_used": time.time(),
            "hits": 0,
        }
        # 同一首歌可能被两把键指向（quick 键只带歌名，exact 键带音源标题），
        # 它们会各自写出一个独立文件，于是 /歌单 把同一首歌显示两遍，
        # 看着像存重了，还白占一份磁盘。
        # 按「语义」去重：歌名+模式+片段+变调相同即视为同一首歌，
        # 删掉旧条目和它的物理文件，只留刚写入的这条。
        sem = (song, mode, int(seconds), int(start), int(pitch))
        dup = [
            (k, v) for k, v in entries.items()
            if k != key and (v.get("song"), v.get("mode"), v.get("seconds"),
                             v.get("start"), v.get("pitch")) == sem
        ]
        for k, v in dup:
            try:
                (CACHE_DIR / v.get("file", "")).unlink(missing_ok=True)
            except Exception:
                pass
            entries.pop(k, None)
        if dup:
            logger.info("[sing] 合并重复条目 %d 条（%s）", len(dup), song)
        # LRU 淘汰：按 last_used 升序删，直到不超上限
        if CACHE_MAX > 0 and len(entries) > CACHE_MAX:
            ordered = sorted(entries.items(), key=lambda kv: kv[1].get("last_used", 0))
            remove_n = len(entries) - CACHE_MAX
            for k, v in ordered[:remove_n]:
                try:
                    (CACHE_DIR / v.get("file", "")).unlink(missing_ok=True)
                except Exception:
                    pass
                entries.pop(k, None)
            logger.info("[sing] 缓存超上限，淘汰 %d 首（上限 %d）", remove_n, CACHE_MAX)
        _cache_save(data)
        return dst
    except Exception as exc:
        logger.warning("[sing] 写入缓存失败（不影响本次发送）：%s", exc)
        return src_file


def _cache_stats() -> dict:
    data = _cache_load()
    entries = data.get("entries") or {}
    total = sum(int(e.get("bytes", 0)) for e in entries.values())
    oldest = None
    if entries:
        oldest = min(entries.values(), key=lambda e: e.get("last_used", 0))
    return {
        "count": len(entries),
        "max": CACHE_MAX,
        "bytes": total,
        "oldest": (oldest or {}).get("title") or "",
        "oldest_song": (oldest or {}).get("song") or "",
    }


def _parse_clock(text: str):
    """"1:57" / "1:02:03" → 秒。"""
    parts = str(text or "").split(":")
    if not parts or any(p == "" for p in parts):
        return None
    try:
        return sum(int(p) * (60 ** i) for i, p in enumerate(reversed(parts)))
    except ValueError:
        return None


async def _run(cmd: list, timeout: int = 120) -> str:
    """执行外部命令，失败时抛出带最后几行 stderr 的错误。"""
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        out, err = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        raise RuntimeError(f"{Path(cmd[0]).name} 超时（{timeout}s）")
    if proc.returncode != 0:
        detail = (err or b"").decode("utf-8", "ignore").strip().splitlines()
        tail = " | ".join(detail[-3:]) if detail else ""
        raise RuntimeError(
            f"{Path(cmd[0]).name} 失败（code={proc.returncode}）"
            + (f"：{tail}" if tail else "")
        )
    return (out or b"").decode("utf-8", "ignore")


def _unique_voice_path(name: str) -> Path:
    """语音库里不重名的目标路径。"""
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    ext = Path(name).suffix
    base = name[: len(name) - len(ext)]
    candidate = VOICE_DIR / name
    i = 2
    while candidate.exists():
        candidate = VOICE_DIR / f"{base}-{i}{ext}"
        i += 1
    return candidate


# ---------------------------------------------------------------- 搜歌
# B站风控说明：只有 UA + Referer 时，第二次起就返回 412 Precondition Failed
# （实测：docker 里首条 OK，随后立刻 412）。带上 buvid3 等一系列 cookie
# 才能稳定通过。这里先在容器内取一次首页 cookie 并缓存 30 分钟。
_BILI_COOKIE = {"text": "", "ts": 0.0}


def _bili_cookie() -> str:
    """获取 B站匿名 cookie（buvid3 等），30 分钟内复用。"""
    import urllib.request

    now = time.time()
    if _BILI_COOKIE["text"] and now - _BILI_COOKIE["ts"] < 1800:
        return _BILI_COOKIE["text"]

    parts = []
    for url in ("https://www.bilibili.com/", "https://api.bilibili.com/x/frontend/finger/spi"):
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": UA,
                    "Referer": "https://www.bilibili.com/",
                    "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
                    "Accept-Language": "zh-CN,zh;q=0.9",
                },
            )
            with urllib.request.urlopen(req, timeout=20) as r:
                for k, v in r.headers.get_all("Set-Cookie") or []:
                    pair = v.split(";")[0].strip()
                    if "=" in pair:
                        parts.append(pair)
                # 第二个接口把 buvid 放在 JSON 里
                if "finger" in url:
                    try:
                        data = json.loads(r.read().decode("utf-8", "ignore"))
                        d = data.get("data") or {}
                        if d.get("b_3"):
                            parts.append(f"buvid3={d['b_3']}")
                        if d.get("b_4"):
                            parts.append(f"buvid4={d['b_4']}")
                    except Exception:
                        pass
        except Exception as exc:
            logger.debug("[sing] 取 bilibili cookie 失败(%s)：%s", url, exc)

    # 去重，保持顺序
    seen, uniq = set(), []
    for p in parts:
        key = p.split("=")[0]
        if key in seen:
            continue
        seen.add(key)
        uniq.append(p)
    text = "; ".join(uniq)

    # 没有 buvid3 时报 412 的概率很高，补一个随机值兜底
    if "buvid3=" not in text:
        text = (text + "; " if text else "") + f"buvid3={uuid.uuid4()}infoc"

    _BILI_COOKIE.update({"text": text, "ts": now})
    return text


async def _search_bilibili(query: str, limit: int) -> list:
    """B 站公开搜索接口，带匿名 cookie 绕 412。"""
    import urllib.parse
    import urllib.request

    loop = asyncio.get_running_loop()
    cookie = await loop.run_in_executor(None, _bili_cookie)

    url = (
        "https://api.bilibili.com/x/web-interface/search/type"
        f"?search_type=video&keyword={urllib.parse.quote(query)}&page=1"
    )
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Referer": f"https://search.bilibili.com/all?keyword={urllib.parse.quote(query)}",
            "Origin": "https://www.bilibili.com",
            "Cookie": cookie,
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "zh-CN,zh;q=0.9",
        },
    )
    loop = asyncio.get_running_loop()

    def _fetch():
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read().decode("utf-8", "ignore"))

    data = await loop.run_in_executor(None, _fetch)
    if data.get("code") != 0:
        raise RuntimeError(f"B站接口 code={data.get('code')} {data.get('message', '')}")

    results = []
    for item in (data.get("data") or {}).get("result") or []:
        title = re.sub(r"<[^>]+>", "", str(item.get("title", "")))
        title = title.replace("&amp;", "&").replace("&quot;", '"').strip()
        bvid = item.get("bvid")
        if not title or not bvid:
            continue
        results.append(
            {
                "title": title,
                "url": f"https://www.bilibili.com/video/{bvid}",
                "duration": _parse_clock(item.get("duration")),
                "uploader": re.sub(r"<[^>]+>", "", str(item.get("author", ""))).strip(),
                "source": "bilibili",
            }
        )
        if len(results) >= limit:
            break
    return results


async def _search_songs(query: str, limit: int = SEARCH_LIMIT) -> list:
    """B 站优先，yt-dlp 兜底。"""
    errors = []
    try:
        hits = await _search_bilibili(query, limit)
        if hits:
            return hits
    except Exception as exc:
        errors.append(f"bilibili-api: {exc}")
        logger.warning("[sing] B站搜索失败：%s", exc)

    if YTDLP:
        for prefix, source in ((f"ytsearch{limit}:", "youtube"),):
            try:
                out = await _run(
                    [YTDLP, "--no-warnings", "--ignore-errors", "-J", f"{prefix}{query}"],
                    timeout=120,
                )
                import json

                doc = json.loads(out)
                entries = []
                for e in (doc.get("entries") or []):
                    if not e:
                        continue
                    entries.append(
                        {
                            "title": str(e.get("fulltitle") or e.get("title") or "").strip(),
                            "url": str(e.get("webpage_url") or e.get("url") or "").strip(),
                            "duration": e.get("duration"),
                            "uploader": e.get("uploader"),
                            "source": source,
                        }
                    )
                if entries:
                    return [e for e in entries if e["url"]]
            except Exception as exc:
                errors.append(f"{source}: {exc}")

    raise RuntimeError(f"搜索失败：{' / '.join(errors) or '没有结果'}")


def _pick_candidate(results: list, hint: str) -> dict:
    """挑最匹配的那条：先排除伴奏等噪声，再看标题是否含关键词。"""
    clean = []
    for r in results:
        title = r["title"]
        if any(w in title for w in _BAD_WORDS):
            continue
        clean.append(r)
    pool = clean or results
    # 标题里同时含歌名关键词的优先
    hints = [h for h in hint.split() if h]
    scored = []
    for r in pool:
        score = sum(1 for h in hints if h in r["title"])
        scored.append((score, r))
    scored.sort(key=lambda x: -x[0])
    return scored[0][1]


# ---------------------------------------------------------------- 音频处理
async def _download(url: str, out_base: Path) -> Path:
    """下载最佳音轨并转 mp3（只留音频）。"""
    if not YTDLP:
        raise RuntimeError("缺少 yt-dlp")
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    await _run(
        [
            YTDLP, "--no-warnings", "--ignore-errors",
            "-f", "bestaudio/best",
            "-x", "--audio-format", "mp3", "--audio-quality", "5",
            "--ffmpeg-location", str(Path(FFMPEG).parent),
            "-o", f"{out_base}.%(ext)s",
            "--no-playlist",
            url,
        ],
        timeout=300,
    )
    for ext in ("mp3", "m4a", "webm", "opus", "aac", "wav"):
        c = Path(f"{out_base}.{ext}")
        if c.exists() and c.stat().st_size > 1024:
            return c
    raise RuntimeError("下载完成但没找到音频文件")


async def _cut(src: Path, out: Path, start: float, seconds: int) -> Path:
    """截一段，转 44.1k 立体声 mp3。"""
    out.parent.mkdir(parents=True, exist_ok=True)
    await _run(
        [
            FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
            "-ss", str(max(0, start)), "-t", str(seconds),
            "-i", str(src),
            "-ar", "44100", "-ac", "2", "-b:a", "192k",
            str(out),
        ],
        timeout=120,
    )
    if not out.exists() or out.stat().st_size < 1024:
        raise RuntimeError("裁剪失败：输出为空")
    return out


async def _probe_duration(src: Path):
    try:
        await _run(
            [FFMPEG, "-hide_banner", "-i", str(src), "-f", "null", "-"], timeout=60
        )
    except RuntimeError as exc:
        # ffmpeg 把时长写在 stderr，非零退出也可能有
        text = str(exc)
        m = re.search(r"(\d+):(\d+):(\d+(?:\.\d+)?)", text)
        if m:
            return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
        return None
    return None


async def _separate_vocals(input_mp3: Path, work: Path):
    """demucs 分离人声/伴奏（CPU）。"""
    out_dir = work / "demucs"
    await _run(
        [
            str(VENV_PY), "-m", "demucs", "-n", DEMUCS_MODEL,
            "--two-stems=vocals",
            "-d", "cpu",                      # 本机无可用 GPU
            "-o", str(out_dir),
            str(input_mp3),
        ],
        timeout=1800,
    )
    base = input_mp3.stem
    vocals = out_dir / DEMUCS_MODEL / base / "vocals.wav"
    instrumental = out_dir / DEMUCS_MODEL / base / "no_vocals.wav"
    if not vocals.exists() or not instrumental.exists():
        raise RuntimeError("人声分离失败：没有生成 vocals / no_vocals")
    return vocals, instrumental


async def _convert_voice(src_wav: Path, out_wav: Path, pitch: int = 0) -> Path:
    """用流萤音色跑 RVC。"""
    if not COVER_SCRIPT.exists():
        raise RuntimeError("缺少 RVC 驱动脚本 sing/cover.py")
    await _run(
        [str(VENV_PY), str(COVER_SCRIPT), str(src_wav), str(out_wav), str(pitch), "rmvpe"],
        timeout=1800,
    )
    if not out_wav.exists() or out_wav.stat().st_size < 1024:
        raise RuntimeError("RVC 转换失败：输出为空")
    return out_wav


async def _mix(vocals_wav: Path, instrumental_wav: Path, out: Path, seconds: int) -> Path:
    """混成成品。"""
    out.parent.mkdir(parents=True, exist_ok=True)
    await _run(
        [
            FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(vocals_wav), "-i", str(instrumental_wav),
            "-filter_complex",
            "[0:a]volume=1.0[v];[1:a]volume=0.72[i];"
            "[v][i]amix=inputs=2:duration=longest:dropout_transition=0:normalize=0[out]",
            "-map", "[out]", "-t", str(seconds),
            "-ar", "44100", "-ac", "2", "-b:a", "192k",
            str(out),
        ],
        timeout=180,
    )
    if not out.exists() or out.stat().st_size < 1024:
        raise RuntimeError("混音失败：输出为空")
    return out


# ---------------------------------------------------------------- 环境自检
async def _readiness() -> dict:
    checks = {
        "ytdlp": {"ok": bool(YTDLP), "path": YTDLP},
        "ffmpeg": {"ok": bool(FFMPEG), "path": FFMPEG},
        "venv": {"ok": VENV_PY.exists(), "path": str(VENV_PY)},
        "rvc": {"ok": RVC_DIR.exists(), "path": str(RVC_DIR)},
        "coverScript": {"ok": COVER_SCRIPT.exists(), "path": str(COVER_SCRIPT)},
        "voiceModel": {"ok": VOICE_MODEL.exists(), "path": str(VOICE_MODEL)},
        "torch": {"ok": False, "detail": "未检测"},
        "demucs": {"ok": False, "detail": "未检测"},
    }
    if checks["venv"]["ok"]:
        try:
            out = await _run(
                [str(VENV_PY), "-c", "import torch,sys;print(torch.__version__)"],
                timeout=60,
            )
            checks["torch"] = {"ok": True, "detail": out.strip()}
        except Exception as exc:
            checks["torch"] = {"ok": False, "detail": str(exc)[:180]}
        try:
            await _run([str(VENV_PY), "-c", "import demucs"], timeout=60)
            checks["demucs"] = {"ok": True, "detail": "已安装"}
        except Exception:
            checks["demucs"] = {"ok": False, "detail": "未安装（pip install demucs）"}
    return checks


def _missing_for_ai(checks: dict) -> list:
    """AI 翻唱缺什么，一次列全（不静默降级）。"""
    missing = []
    if not checks["venv"]["ok"]:
        missing.append("Python venv（sing/venv）")
    if not checks["torch"]["ok"]:
        missing.append(f"PyTorch（{checks['torch'].get('detail', '未安装')}）")
    if not checks["demucs"]["ok"]:
        missing.append("demucs（人声分离）")
    if not checks["rvc"]["ok"]:
        missing.append("RVC 推理代码（sing/rvc_cli）")
    if not checks["coverScript"]["ok"]:
        missing.append("RVC 驱动脚本（sing/cover.py）")
    if not checks["voiceModel"]["ok"]:
        missing.append("流萤音色模型（sing/model/liuying.pth）")
    return missing


# ---------------------------------------------------------------- 插件主体
class SingPlugin(star.Star):
    """流萤音色唱歌插件"""

    def __init__(self, context, config=None):
        super().__init__(context, config)

    # -------- 权限 ------
    def _is_owner(self, event: AstrMessageEvent) -> bool:
        return str(event.get_sender_id()) == OWNER_ID

    def _allow(self, mode: str) -> bool:
        """按 GROUP_ACCESS 判断群友能否用某个模式。"""
        if GROUP_ACCESS in ("ai", "all"):
            return True
        if GROUP_ACCESS == "original":
            return mode == "original"
        return False        # owner

    def _deny(self, event: AstrMessageEvent, mode: str = "ai") -> bool:
        """返回 True 表示拒绝。"""
        if self._is_owner(event):
            return False
        return not self._allow(mode)

    # -------- /唱歌状态 ------
    # 为什么全部改成 @filter.regex：
    # AstrBot 的 CommandFilter 第 192 行要求 event.is_at_or_wake_command，
    # 且第 202 行用 message_str.startswith("/唱歌 ") 判定。群里 @ 机器人时
    # NapCat 给的是 raw_message="@小鲸鱼 /唱歌 全球变冷"，@ 和正文在同一个
    # Plain 段（comps 实测只有 ['Plain']，没有独立 At 段），于是 message_str
    # 以 "@小鲸鱼" 开头，startswith 永远不成立 —— 命令根本不触发，
    # 消息落到大模型，模型就会回「唱不了」。
    # RegexFilter 的源码注释写明「不会受到 wake_prefix 的制约」，是唯一稳的路。
    @filter.regex(r"^\s*(?:@\S+\s*)?/?唱歌状态\s*$")
    async def cmd_status(self, event: AstrMessageEvent):
        """检查唱歌链路是否就绪"""
        checks = await _readiness()
        lines = ["🎤 唱歌链路自检"]
        for key, label in (
            ("ytdlp", "yt-dlp"), ("ffmpeg", "ffmpeg"), ("venv", "Python venv"),
            ("torch", "PyTorch"), ("demucs", "demucs"), ("rvc", "RVC 代码"),
            ("coverScript", "cover.py"), ("voiceModel", "流萤音色模型"),
        ):
            c = checks[key]
            mark = "✅" if c["ok"] else "❌"
            detail = c.get("detail") or c.get("path") or ""
            if len(str(detail)) > 60:
                detail = str(detail)[:60] + "…"
            lines.append(f"{mark} {label}" + (f"  {detail}" if detail else ""))

        missing = _missing_for_ai(checks)
        lines.append("")
        if missing:
            lines.append(f"AI 翻唱未就绪，缺少：{'、'.join(missing)}")
        else:
            lines.append("AI 翻唱已就绪 ✅")
        lines.append(f"默认片段 {DEFAULT_SECONDS}s，上限 {MAX_SECONDS}s")

        # 成品缓存概况
        cst = _cache_stats()
        lines.append(
            f"缓存：{cst['count']}/{cst['max']} 首"
            + (f"，{cst['bytes'] // 1048576}MB" if cst["bytes"] else "")
        )
        # 权限与限流信息（方便群里自查为什么被拒）
        acc = {
            "owner": "仅主人",
            "original": "群友可用 /原唱",
            "ai": "群友可用 /原唱 + /唱歌",
            "all": "群友可用 /原唱 + /唱歌",
        }.get(GROUP_ACCESS, GROUP_ACCESS)
        lines.append(f"权限：{acc}（主人始终可用）")
        if GROUP_ACCESS != "owner":
            lines.append(
                f"群友限制：片段 ≤{MAX_SECONDS_GROUP}s，"
                f"个人冷却 {COOLDOWN_USER}s，本群冷却 {COOLDOWN_GROUP}s，同时只做一首"
            )

        # 当前是否在跑、最近一条任务的结果（独立于容器日志，重建也查得到）
        lock = _busy_lock()
        if lock.locked() and _CURRENT["step"]:
            el = int(time.time() - _CURRENT["since"])
            lines.append(f"⏳ 正在做「{_CURRENT['song']}」，当前步骤 {_CURRENT['step']}，已 {el}s")
        else:
            lines.append("💤 当前空闲")
        last = _read_last_status()
        if last:
            lines.append(
                f"最近一次：{last.get('ts','')} {last.get('event','')}"
                f"「{last.get('song','')}」"
                + (f" 失败/说明：{str(last.get('detail'))[:80]}"
                   if last.get("detail") else "")
            )
        event.set_result(event.plain_result("\n".join(lines)))

    # -------- /搜歌 ------
    @filter.regex(r"^\s*(?:@\S+\s*)?/?搜歌(?:\s+|$)")
    async def cmd_search(self, event: AstrMessageEvent):
        """/搜歌 <歌名> —— 只列候选"""
        query = (event.message_str or "").strip()
        query = re.sub(r"^\s*(?:@\S+\s*)?", "", query)          # 去 @ 前缀
        query = re.sub(r"^/?搜歌\s*", "", query).strip()
        if not query:
            event.set_result(event.plain_result("用法：/搜歌 夜曲"))
            return
        try:
            results = await _search_songs(query, SEARCH_LIMIT)
        except Exception as exc:
            event.set_result(event.plain_result(f"搜歌失败：{exc}"))
            return

        lines = [f"🔍 「{query}」候选："]
        for i, r in enumerate(results, 1):
            dur = ""
            if r.get("duration"):
                sec = int(r["duration"])
                dur = f" [{sec // 60}:{sec % 60:02d}]"
            up = f" - {r['uploader']}" if r.get("uploader") else ""
            lines.append(f"{i}. {r['title']}{dur}{up}")
            lines.append(f"   {r['url']}")
        lines.append("")
        lines.append("用 /唱歌 <歌名> 直接唱，或 /唱歌 <歌名> 候选=2 选指定版本")
        lines.append("用 /歌单 查看已唱过的曲库（命中缓存可秒发）")
        event.set_result(event.plain_result("\n".join(lines)))

    # -------- /歌单 ------
    @filter.regex(r"^\s*(?:@\S+\s*)?/?歌单\s*$")
    async def cmd_songlist(self, event: AstrMessageEvent):
        """/歌单 —— 查看已唱过的成品缓存（LRU 淘汰，上限 100 首）"""
        data = _cache_load()
        entries = data.get("entries") or {}
        if not entries:
            event.set_result(event.plain_result(
                "曲库还是空的，唱一首就会存进来（上限 100 首，超出淘汰最久未用的）"))
            return
        # 按最近使用排序，主人能看全，群友只看前 10（避免刷屏）
        ordered = sorted(entries.values(), key=lambda e: -e.get("last_used", 0))
        show = ordered if self._is_owner(event) else ordered[:10]
        total_mb = sum(int(e.get("bytes", 0)) for e in ordered) // 1048576
        lines = [f"🎵 曲库 {len(ordered)}/{CACHE_MAX} 首"
                 + (f"，共 {total_mb}MB" if total_mb else "")]
        for i, e in enumerate(show, 1):
            sec = int(e.get("seconds", 0))
            tag = "AI" if e.get("mode") == "ai" else "原"
            hits = int(e.get("hits", 0))
            lines.append(
                f"{i}. [{tag}] {e.get('song','?')} {sec}s"
                + (f" · 复用{hits}次" if hits else "")
            )
        if not self._is_owner(event) and len(ordered) > len(show):
            lines.append(f"……还有 {len(ordered) - len(show)} 首，主人可看全部")
        lines.append("")
        # 记下这次展示的歌单，供「选 <数字>」/裸数字回选使用。
        # 键用会话 UMO，避免不同群串；同时记发单人，裸数字只认他本人，
        # 否则群里任何人打「1」都会被我截走，那才是灾难。
        _SHOWN[_umo(event)] = {
            "entries": show,
            "ts": time.time(),
            "uid": str(event.get_sender_id()),
        }
        lines.append("回「选 <数字>」直接把已存的那首发出来（例：选 1）")
        event.set_result(event.plain_result("\n".join(lines)))

    # -------- /选 <数字> 与裸数字回选 ------
    # 为什么需要它：/歌单 只列出来，用户顺手回个「1」时代码无处可接，
    # 消息就落到大模型 —— 实测它把**另一个机器人**发的歌单当成了我们的，
    # 「1」被答成「那就十年」，用户完全得不到想要的音频。
    # 规则：
    #   「选 1 / 听 2 / 要 3 / 来 4」→ 本会话任何人可用
    #   裸「1」「2」→ 只有**刚发 /歌单 的那个人**、且在 10 分钟内才认
    # 这样既不误伤群聊，又贴住"看完列表顺手回个数字"的真实习惯。
    @filter.regex(r"^\s*(?:@\S+\s*)?(?:(?:选|听|要|来)\s*)?(\d{1,3})\s*$")
    async def cmd_pick(self, event: AstrMessageEvent):
        """从最近一次 /歌单 里挑一首直接发成品"""
        raw = event.message_str or ""
        m = re.match(r"^\s*(?:@\S+\s*)?(?:(?:选|听|要|来)\s*)?(\d{1,3})\s*$", raw)
        if not m:
            return
        idx = int(m.group(1))
        # 是否带了「选/听/要/来」这个显式动词
        explicit = bool(re.search(r"(?:选|听|要|来)\s*\d", raw))

        shown = _SHOWN.get(_umo(event))
        if not shown:
            # 没展示过歌单：裸数字当闲聊放行，让大模型正常处理
            if not explicit:
                return
            event.set_result(event.plain_result(
                "先发 /歌单 看曲库，再用「选 1」挑"))
            return
        if time.time() - shown.get("ts", 0) > 600:
            if not explicit:
                return
            event.set_result(event.plain_result(
                "歌单太久了（超过 10 分钟），重新发一次 /歌单 吧"))
            return
        # 裸数字：只认发歌单那个人
        if not explicit and str(event.get_sender_id()) != shown.get("uid"):
            return

        ents = shown.get("entries") or []
        if idx < 1 or idx > len(ents):
            if not explicit:
                return
            event.set_result(event.plain_result(
                f"只有 1~{len(ents)} 首，你选的是 {idx}"))
            return
        e = ents[idx - 1]
        path = CACHE_DIR / (e.get("file") or "")
        if not path.exists():
            event.set_result(event.plain_result(
                f"「{e.get('song')}」的缓存文件不在了，重新 /唱歌 一次吧"))
            return
        _step("send")
        try:
            await event.send(MessageChain(
                chain=[Record.fromFileSystem(str(path))]))
        except BaseException as exc:
            detail = str(exc).strip().replace("\n", " ")[:100]
            logger.warning("[sing] 缓存发送失败：%s", detail)
            event.set_result(event.plain_result(f"没发出去（{detail}）"))
            return
        tag = "流萤音色" if e.get("mode") == "ai" else "原唱"
        logger.info("[sing] 选 %d 发送缓存：%s", idx, e.get("song"))
        event.set_result(event.plain_result(
            f"🎶 {e.get('song')}（{tag} · {int(e.get('seconds', 0))}s）"))

    # -------- /原唱 ------
    @filter.regex(r"^\s*(?:@\S+\s*)?/?原唱(?:\s+|$)")
    async def cmd_original(self, event: AstrMessageEvent):
        """/原唱 <歌名> —— 发原唱片段"""
        if self._deny(event, "original"):
            event.set_result(event.plain_result(
                "原唱需要主人权限（群友可用模式由 DSH_SING_GROUP_ACCESS 控制）"))
            return
        await self._do_cover(event, mode="original")

    # -------- /唱歌（别名 翻唱）------
    # 注意：@filter.command 只能叠一层（实测多层叠加另一层不生效），
    # 所以拆成两个方法共用实现；且必须用 regex 才能穿透 @ 前缀。
    @filter.regex(r"^\s*(?:@\S+\s*)?/?唱歌(?:\s+|$)")
    async def cmd_sing(self, event: AstrMessageEvent):
        """/唱歌 <歌名> —— AI 音色翻唱"""
        if self._deny(event, "ai"):
            event.set_result(event.plain_result(
                "AI 翻唱需要主人权限。群友可以试试 /原唱 <歌名>（秒出）"))
            return
        await self._do_cover(event, mode="ai")

    @filter.regex(r"^\s*(?:@\S+\s*)?/?翻唱(?:\s+|$)")
    async def cmd_cover(self, event: AstrMessageEvent):
        """/翻唱 <歌名> —— /唱歌 的别名"""
        if self._deny(event, "ai"):
            event.set_result(event.plain_result(
                "AI 翻唱需要主人权限。群友可以试试 /原唱 <歌名>（秒出）"))
            return
        await self._do_cover(event, mode="ai")

    # -------- 核心流程 ------
    async def _do_cover(self, event: AstrMessageEvent, mode: str):
        raw = (event.message_str or "").strip()
        # 必须先剥 @ 前缀再剥命令词：群里 @机器人 时 message_str 形如
        # "@小鲸鱼 /唱歌 全球变冷"，顺序颠倒会把歌名切成 "@小鲸鱼 ..."。
        raw = re.sub(r"^\s*@\S+\s*", "", raw)
        raw = re.sub(r"^/?(?:唱歌|翻唱|原唱)\s*", "", raw).strip()
        if not raw:
            event.set_result(event.plain_result("用法：/唱歌 夜曲"))
            return

        # 解析可选参数：候选=2 时长=60 起=30 变调=12
        candidate = 1
        seconds = DEFAULT_SECONDS
        start = 0.0
        pitch = 0
        song = raw
        for key, setter in (
            ("候选", "c"), ("时长", "s"), ("起", "t"), ("变调", "p")
        ):
            m = re.search(rf"{key}[=＝]([0-9]+)", raw)
            if m:
                val = int(m.group(1))
                if setter == "c":
                    candidate = max(1, min(8, val))
                elif setter == "s":
                    seconds = max(5, min(MAX_SECONDS, val))
                elif setter == "t":
                    start = float(val)
                elif setter == "p":
                    pitch = max(-24, min(24, val))
                song = raw.replace(m.group(0), "").strip()
        song = re.sub(r"\s+", " ", song).strip()
        if not song:
            event.set_result(event.plain_result("歌名不能为空"))
            return

        # ---------- 限流（主人不受限）----------
        is_owner = self._is_owner(event)
        if not is_owner:
            # 群友不做长片段：CPU 上 60s 要 5-6 分钟，会堵住整个群
            seconds = min(seconds, MAX_SECONDS_GROUP)
            sender = str(event.get_sender_id())
            umo = event.unified_msg_origin or ""
            now = time.time()

            # 1) 个人冷却
            last = LAST_USE.get(f"u:{sender}", 0)
            if now - last < COOLDOWN_USER:
                wait = int(COOLDOWN_USER - (now - last))
                event.set_result(event.plain_result(
                    f"刚唱过啦，{wait} 秒后再来～"
                ))
                return
            # 2) 本群冷却
            lastg = LAST_USE.get(f"g:{umo}", 0)
            if now - lastg < COOLDOWN_GROUP:
                wait = int(COOLDOWN_GROUP - (now - lastg))
                event.set_result(event.plain_result(
                    f"这个群刚唱完，{wait} 秒后再点吧"
                ))
                return
            # 3) 全局忙：只排队等一会儿，不无限阻塞
            if _BUSY["lock"] is not None and _BUSY["lock"].locked():
                event.set_result(event.plain_result(
                    "前面还有人点歌，我正唱着，等下一首吧"
                ))
                return

        # AI 模式先检查环境，缺什么一次列全
        if mode == "ai":
            checks = await _readiness()
            missing = _missing_for_ai(checks)
            if missing:
                event.set_result(
                    event.plain_result(
                        f"AI 翻唱未就绪，缺少：{'、'.join(missing)}\n"
                        "可以先用 /原唱 发原唱片段。"
                    )
                )
                return

        await event.send(event.plain_result(
            f"🎵 正在处理「{song}」（{'AI 翻唱' if mode == 'ai' else '原唱'}）"
            f"，CPU 模式可能需要 1-3 分钟…"
        ))

        work = None
        # 全局锁：同一时刻只做一个重活（4 核 CPU 撑不住并行 RVC）。
        # 主人同样排队，但主人不因冷却被拒。
        _CURRENT["song"] = song
        lock = _busy_lock()
        try:
            await asyncio.wait_for(lock.acquire(), timeout=QUEUE_WAIT_MAX)
        except asyncio.TimeoutError:
            await event.send(event.plain_result("排队太久啦，稍后再点一首吧"))
            return

        try:
            # ---------- 缓存优先：命中就直接发，不做任何 CPU 重活 ----------
            # 键是纯语义的（歌名+模式+时长+起点+变调），不需要先搜歌
            # 拿到音源标题，所以命中路径完全离线，真正做到秒回。
            _step("cache")
            ckey = _cache_key(song, mode, seconds, start, pitch)
            hit = _cache_get(ckey)
            if hit:
                _status_write(event="ok", bytes=hit.stat().st_size,
                              file=str(hit.name), cached=True, song=song)
                _step("send")
                try:
                    await event.send(MessageChain(
                        chain=[Record.fromFileSystem(str(hit))]))
                except BaseException as exc:
                    detail = str(exc).strip().replace("\n", " ")[:120]
                    logger.warning("[sing] 缓存语音发送失败：%s", detail)
                    await event.send(event.plain_result(
                        f"找到了缓存但没发出去（{detail}）"))
                    return
                logger.info("[sing] 缓存直接发送成功 song=%s", song)
                await event.send(event.plain_result(
                    f"🎶 「{song}」之前唱过，直接给你\n"
                    f"{'流萤音色翻唱' if mode == 'ai' else '原唱片段'} · "
                    f"{seconds}s · {hit.stat().st_size // 1024}KB"
                ))
                return

            _step("search")
            results = await _search_songs(song, SEARCH_LIMIT)
            picked = _pick_candidate(results, song)
            logger.info("[sing] 选中：%s (%s)", picked["title"], picked["url"])

            work = WORK_DIR / f"{'ai' if mode == 'ai' else 'src'}-{_stamp()}"
            work.mkdir(parents=True, exist_ok=True)
            _status_write(event="start", song=song, mode=mode, seconds=seconds,
                          title=picked["title"], work=str(work.name))

            _step("download")
            downloaded = await _download(picked["url"], work / "src")
            total = await _probe_duration(downloaded)
            max_start = max(0, (total or 60) - seconds - 1)
            # 记住调用方原始请求的 start，入库缓存时用它。
            # 若用 clamp 后的值，用户传 start=0 而实际被修正为 12 时，
            # 下次同样的 start=0 就查不到自己的缓存 —— 实测踩过。
            req_start = start
            start = min(start, max_start)

            out_name = f"sing-{_slugify(picked['title'] or song)}" \
                       f"{'-ai' if mode == 'ai' else ''}-{_stamp()}.mp3"
            out_file = _unique_voice_path(out_name)

            if mode == "original":
                _step("cut")
                await _cut(downloaded, out_file, start, seconds)
                downloaded.unlink(missing_ok=True)
            else:
                _step("cut")
                clip_wav = work / "clip.wav"
                await _cut(downloaded, clip_wav, start, seconds)
                downloaded.unlink(missing_ok=True)

                _step("demucs")          # 最长的一步（30s 片段约 100s）
                vocals, instrumental = await _separate_vocals(clip_wav, work)

                _step("rvc")             # 第二长（30s 片段约 60s）
                converted = work / "vocals-ai.wav"
                await _convert_voice(vocals, converted, pitch)

                _step("mix")
                await _mix(converted, instrumental, out_file, seconds)

            # ---- 发送语音（单独一条，不塞 result_chain）----
            _step("send")
            try:
                await event.send(MessageChain(chain=[Record.fromFileSystem(str(out_file))]))
            except BaseException as exc:
                detail = str(exc).strip().replace("\n", " ")[:120]
                logger.warning("[sing] 语音发送失败：%s", detail)
                _status_write(event="send_failed", detail=detail,
                              file=str(out_file.name))
                await event.send(event.plain_result(f"语音制作好了但没发出去（{detail}）"))
                return

            logger.info(
                "[sing] 发送成功 mode=%s title=%s bytes=%d source=%s",
                mode, picked["title"], out_file.stat().st_size, picked["source"],
            )
            # 存进缓存（发送成功才存，避免把失败产物喂给下次）
            _cache_put(ckey, out_file, song, mode, seconds, req_start, pitch,
                       picked["title"], picked["source"])
            _status_write(event="ok", bytes=out_file.stat().st_size,
                          file=str(out_file.name))
            await event.send(event.plain_result(
                f"🎶 {picked['title']}\n"
                f"{'流萤音色翻唱' if mode == 'ai' else '原唱片段'} · "
                f"{seconds}s · {out_file.stat().st_size // 1024}KB"
            ))

        except Exception as exc:
            logger.error("[sing] 制作失败：%s", exc, exc_info=True)
            _status_write(event="fail", detail=str(exc)[:300])
            # 群聊失败提示保持简短（原文档要求）
            brief = str(exc).splitlines()[0][:120]
            await event.send(event.plain_result(f"唱歌失败：{brief}"))
        finally:
            if lock.locked():
                lock.release()
            # 记录冷却时间（成功失败都记，避免失败后立刻重试刷屏）
            now = time.time()
            try:
                LAST_USE[f"u:{event.get_sender_id()}"] = now
                LAST_USE[f"g:{event.unified_msg_origin or ''}"] = now
            except Exception:
                pass
            if work and work.exists():
                shutil.rmtree(work, ignore_errors=True)
