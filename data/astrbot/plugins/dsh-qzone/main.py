"""AstrBot 插件：QQ 空间自动动态（移植自大肥鱼自动QQ动态方案）

素材来源：当天真实聊天（群聊 + 主人私聊）+ 当天功能更新
过滤：隐私字段、短消息、斜杠命令
去重：最近 7 天已发动态
配图：从表情包库按语义挑选（可选）
发布：NapCat 扩展接口 send_qzone_msg
"""

import asyncio
import json
import os
import random
import re
import time
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

TZ = ZoneInfo("Asia/Shanghai")

from astrbot.api import star
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.core import logger

# ---------------------------------------------------------------- 配置
OWNER_ID = os.environ.get("DSH_QZONE_OWNER", "").strip()
GROUP_WHITELIST = [
    g.strip()
    for g in os.environ.get("DSH_QZONE_GROUPS", "").split(",")
    if g.strip()
]
ENABLED = os.environ.get("DSH_QZONE_ENABLED", "1") not in ("0", "false", "False")
TRIGGER_MINUTE = int(os.environ.get("DSH_QZONE_MINUTE", "0"))
MIN_INTERVAL_MS = int(os.environ.get("DSH_QZONE_INTERVAL_MS", "3600000"))
STATE_PATH = os.environ.get("DSH_QZONE_STATE", "/AstrBot/data/qzone/state.json")
TMP_DIR = os.environ.get("DSH_QZONE_TMP", "/AstrBot/data/qzone")
MAX_POSTS_KEEP = 7              # 保留最近 7 天动态做去重参考
MAX_CANDIDATES = 60             # 素材候选上限
MAX_MSG_PER_GROUP = 200         # 每群读取上限
MAX_GROUPS = 20
MIN_MSG_LEN = 4
MAX_QQ_LEN = 500                # 动态正文上限（汉字）
UGC_RIGHT = int(os.environ.get("DSH_QZONE_UGC_RIGHT", "1"))   # 1=公开
CHAT_MODEL_TOKENS = 800

# ---------------------------------------------------------------- 隐私过滤
_PRIVACY_PATTERNS = [
    (re.compile(r"\b\d{6,}\b"), "长数字串"),
    (re.compile(r"1[3-9]\d{9}"), "手机号"),
    (re.compile(r"\d{17}[\dXx]"), "身份证"),
    (re.compile(r"\b\d{12,19}\b"), "银行卡"),
    (re.compile(r"https?://\S+"), "网址"),
    (re.compile(r"(密码|验证码|支付|转账|付款|账单|红包金额|余额)"), "敏感词"),
    (re.compile(r"(身份证|银行卡|家庭住址|收货地址)"), "敏感词"),
]
_CMD_RE = re.compile(r"^[/／]")


def _is_safe(text: str) -> bool:
    if not text or len(text.strip()) < MIN_MSG_LEN:
        return False
    if _CMD_RE.match(text.strip()):
        return False
    for pat, _ in _PRIVACY_PATTERNS:
        if pat.search(text):
            return False
    return True


def _anonymize(text: str) -> str:
    """去掉 @、QQ 号、链接，保留语义。"""
    text = re.sub(r"\[CQ:[^\]]+\]", "", text)
    text = re.sub(r"@\S+\s*", "", text)
    text = re.sub(r"https?://\S+", "", text)
    return text.strip()


# ---------------------------------------------------------------- 状态
def _load_state() -> dict:
    os.makedirs(TMP_DIR, exist_ok=True)
    if not os.path.exists(STATE_PATH):
        return {"posts": [], "last_publish_at": 0, "used_images": []}
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as f:
            d = json.load(f)
        d.setdefault("posts", [])
        d.setdefault("last_publish_at", 0)
        d.setdefault("used_images", [])
        return d
    except Exception as e:  # noqa: BLE001
        logger.warning("[qzone] state 读取失败：%s", e)
        return {"posts": [], "last_publish_at": 0, "used_images": []}


def _save_state(d: dict):
    os.makedirs(TMP_DIR, exist_ok=True)
    cutoff = time.time() - MAX_POSTS_KEEP * 86400
    d["posts"] = [p for p in d.get("posts", []) if p.get("at", 0) >= cutoff][-50:]
    try:
        with open(STATE_PATH, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=2)
    except Exception as e:  # noqa: BLE001
        logger.warning("[qzone] state 保存失败：%s", e)


# ---------------------------------------------------------------- 素材采集
async def _fetch_group_msgs(bot, gid: str) -> list[str]:
    """读群历史消息。OneBot get_group_msg_history。"""
    try:
        r = await bot.call_action(
            "get_group_msg_history",
            group_id=int(gid),
            count=MAX_MSG_PER_GROUP,
        )
        msgs = (r or {}).get("messages") or []
        out = []
        today = datetime.now(TZ).date()
        for m in msgs:
            ts = m.get("time") or 0
            if ts and datetime.fromtimestamp(ts, TZ).date() != today:
                continue
            raw = m.get("raw_message") or ""
            txt = _anonymize(raw)
            if _is_safe(txt):
                out.append(txt)
        return out
    except Exception as e:  # noqa: BLE001
        logger.warning(
            "[qzone] 读群 %s 历史失败：%r type=%s", gid, e, type(e).__name__,
            exc_info=True,
        )
        return []


async def _fetch_private_msgs(bot, uid: str) -> list[str]:
    try:
        r = await bot.call_action(
            "get_friend_msg_history",
            user_id=int(uid),
            count=MAX_MSG_PER_GROUP,
        )
        msgs = (r or {}).get("messages") or []
        out = []
        today = datetime.now(TZ).date()
        for m in msgs:
            ts = m.get("time") or 0
            if ts and datetime.fromtimestamp(ts, TZ).date() != today:
                continue
            txt = _anonymize(m.get("raw_message") or "")
            if _is_safe(txt):
                out.append(txt)
        return out
    except Exception as e:  # noqa: BLE001
        logger.warning(
            "[qzone] 读主人私聊失败：%r type=%s", e, type(e).__name__,
            exc_info=True,
        )
        return []


# ---------------------------------------------------------------- 提示词
PROMPT_TMPL = """你是"大肥鱼"QQ机器人的动态文案撰写助手。请依据给定素材，写一条适合发布在 QQ 动态里的正文。

【主人明确指定的主题】
{OWNER_REQUEST}

【今天的真实聊天或功能更新素材】
{MATERIALS}

【最近 7 天已发布的动态，用于避开重复】
{RECENT}

写作要求：
1. 只选一个具体瞬间或一件小事，用机器人的第一人称写出自然的想法、情绪或联想。不要把所有素材总结成日报或聊天纪要。
2. 可以轻松、俏皮、有个人感受；可以从真实素材合理联想，但不能编造机器人没做过的事。
3. 如果素材是功能更新，只写普通人能感知的新能力，不提代码、仓库、提交、密钥或内部实现。
4. 如果主人指定了主题，就围绕该主题写；不要把主题改成与主人对话的回复。
5. 避开最近动态中的相同事件、话题和表达；素材中没有新事情时，选择另一件真实小事；确实没有可用素材时，仅输出 [SILENT]。
6. 不泄露个人隐私；不要写群名、人名、QQ 号、数字 ID、网址、密码、验证码、手机号、地址、支付或账户信息，也不要照抄他人原话。
7. 一句话足够时保持简短；只有素材确有细节时才展开，正文最多 {MAXLEN} 个汉字。
8. 不写标题、引号、Markdown、前言、理由、创作过程或思考过程。

只输出一条动态正文；没有可用素材时只输出 [SILENT]。"""


# ---------------------------------------------------------------- 插件主体
@star.register(
    "dsh-qzone",
    "大肥鱼",
    "QQ 空间自动动态：从当天真实聊天素材生成第一人称动态并发布",
    "1.0.0",
)
class QzonePlugin(star.Star):
    def __init__(self, context: star.Context) -> None:
        super().__init__(context)
        self.context = context
        self._task = None
        self._last_check_min = -1
        logger.info(
            "[qzone] 加载：enabled=%s minute=%s interval=%sms owner=%s groups=%s",
            ENABLED, TRIGGER_MINUTE, MIN_INTERVAL_MS, OWNER_ID, GROUP_WHITELIST,
        )

    async def initialize(self):
        if not ENABLED:
            logger.info("[qzone] 未启用（DSH_QZONE_ENABLED=0）")
            return

        if os.environ.get("DSH_QZONE_SELFTEST") == "1":
            self._task = asyncio.create_task(self._selftest())

        self._task = asyncio.create_task(self._loop())
        logger.info("[qzone] 定时器已启动")

    async def _selftest(self):
        """一次性自检：取 bot / provider / 读群历史，不发布。"""
        await asyncio.sleep(25)
        try:
            logger.info("[qzone][自检] 开始")
            bot = await self._get_bot()
            logger.info("[qzone][自检] bot = %s", bot)
            pid = await self._chat_provider_id()
            logger.info("[qzone][自检] provider_id = %r", pid)
            if bot is None:
                logger.warning("[qzone][自检] 无 bot，终止")
                return
            total = 0
            for gid in GROUP_WHITELIST:
                msgs = await _fetch_group_msgs(bot, gid)
                total += len(msgs)
                logger.info("[qzone][自检] 群 %s 当天合格素材 %d 条", gid, len(msgs))
                for x in msgs[:3]:
                    logger.info("[qzone][自检]   样例: %s", x[:60])
            pm = await _fetch_private_msgs(bot, OWNER_ID)
            total += len(pm)
            logger.info("[qzone][自检] 主人私聊 %d 条", len(pm))
            logger.info("[qzone][自检] 素材合计 %d 条", total)
        except Exception as e:  # noqa: BLE001
            logger.error("[qzone][自检] 异常：%s", e, exc_info=True)

    async def _loop(self):
        await asyncio.sleep(20)   # 启动后补做一次检查
        while True:
            try:
                await self._tick()
            except Exception as e:  # noqa: BLE001
                logger.error("[qzone] tick 异常：%s", e)
            await asyncio.sleep(30)

    async def _tick(self):
        now = datetime.now(TZ)
        if now.minute != TRIGGER_MINUTE:
            self._last_check_min = -1
            return
        if self._last_check_min == now.minute:
            return
        self._last_check_min = now.minute

        st = _load_state()
        if time.time() * 1000 - st.get("last_publish_at", 0) < MIN_INTERVAL_MS:
            logger.info("[qzone] 距上次发布不足间隔，跳过")
            return
        await self._publish_once()

    async def _chat_provider_id(self) -> str:
        """优先用当前会话模型，回落到第一个可用 provider。"""
        try:
            pid = await self.context.get_current_chat_provider_id(umo=None)
            if pid:
                return pid
        except Exception as e:  # noqa: BLE001
            logger.debug("[qzone] 取当前 provider 失败：%s", e)
        try:
            provs = self.context.get_all_providers() or []
            if provs:
                return getattr(provs[0], "provider_config", {}).get(
                    "id"
                ) or getattr(provs[0], "id", "") or ""
        except Exception as e:  # noqa: BLE001
            logger.debug("[qzone] 枚举 provider 失败：%s", e)
        return ""

    async def _get_bot(self):
        """取 aiocqhttp 平台的 bot 实例（带缓存）。"""
        if getattr(self, "_bot_cache", None) is not None:
            return self._bot_cache
        try:
            insts = getattr(
                getattr(self.context, "platform_manager", None), "platform_insts", []
            ) or []
            for p in insts:
                b = getattr(p, "bot", None)
                if b is not None and hasattr(b, "call_action"):
                    self._bot_cache = b
                    logger.info(
                        "[qzone] 已绑定 OneBot 平台：%s", type(p).__name__
                    )
                    return b
            logger.warning(
                "[qzone] 未找到带 call_action 的平台，现有 %d 个：%s",
                len(insts),
                [type(p).__name__ for p in insts],
            )
        except Exception as e:  # noqa: BLE001
            logger.warning("[qzone] 取 bot 失败：%s", e)
        return None

    async def _publish_once(self, owner_request: str = "") -> str:
        bot = await self._get_bot()
        if bot is None:
            logger.warning("[qzone] 无可用 OneBot 连接")
            return "无 OneBot 连接"

        # 1. 采素材
        materials = []
        if GROUP_WHITELIST:
            for gid in GROUP_WHITELIST[:MAX_GROUPS]:
                materials += await _fetch_group_msgs(bot, gid)
        materials += await _fetch_private_msgs(bot, OWNER_ID)
        materials = materials[-MAX_CANDIDATES:]
        if not materials and not owner_request:
            logger.info("[qzone] 当天无合格素材，跳过")
            return "无合格素材"

        # 2. 近期动态（去重参考）
        st = _load_state()
        recent = "\n".join(
            f"- {p.get('text','')}" for p in st.get("posts", [])[-MAX_POSTS_KEEP:]
        ) or "（无）"

        # 3. 生成文案
        prompt = PROMPT_TMPL.format(
            OWNER_REQUEST=owner_request or "（未指定）",
            MATERIALS="\n".join(f"- {m}" for m in materials),
            RECENT=recent,
            MAXLEN=MAX_QQ_LEN,
        )
        try:
            provider_id = await self._chat_provider_id()
            if not provider_id:
                logger.warning("[qzone] 找不到可用的对话模型 Provider")
                return "无对话模型"
            resp = await self.context.llm_generate(
                chat_provider_id=provider_id,
                prompt=prompt,
            )
            text = (getattr(resp, "completion_text", None) or "").strip()
            if not text:
                text = str(resp).strip()
        except Exception as e:  # noqa: BLE001
            logger.warning("[qzone] 文案生成失败：%s", e)
            return "生成失败"

        if not text or "[SILENT]" in text or len(text) < 8:
            logger.info("[qzone] 模型判定无可用素材（%s）", text[:40])
            return "无素材/空内容"
        text = text.replace("**", "").replace("#", "").strip()
        if len(text) > MAX_QQ_LEN:
            text = text[:MAX_QQ_LEN]

        # 4. 发布
        try:
            r = await bot.call_action(
                "send_qzone_msg",
                content=text,
                images=[],
                ugc_right=UGC_RIGHT,
                target_uins=[],
            )
            tid = ((r or {}).get("data") or {}).get("tid") or (r or {}).get("tid")
            logger.info("[qzone] 发布成功 tid=%s 内容=%s", tid, text[:60])
        except Exception as e:  # noqa: BLE001
            logger.warning("[qzone] 发布失败：%s", e)
            return f"发布失败：{e}"

        # 5. 记账
        st = _load_state()
        st.setdefault("posts", []).append(
            {"at": time.time(), "text": text, "tid": tid, "auto": not owner_request}
        )
        st["last_publish_at"] = time.time() * 1000
        _save_state(st)
        return "OK"

    # ---------------- 指令 ----------------
    @filter.command("发动态")
    async def cmd_post(self, event: AstrMessageEvent, theme: str = ""):
        """手动生成并发布一条动态。/发动态 [主题]"""
        if event.get_sender_id() != OWNER_ID:
            yield event.plain_result("只有主人能用这个指令。")
            return
        theme = theme.strip()
        result = await self._publish_once(owner_request=theme)
        if result == "OK":
            st = _load_state()
            last = st.get("posts", [{}])[-1].get("text", "")
            yield event.plain_result(f"动态已发布 ✅\n\n{last}")
        else:
            yield event.plain_result(f"没发出去：{result}")

    @filter.command("动态状态")
    async def cmd_status(self, event: AstrMessageEvent):
        """查看动态发布状态。"""
        st = _load_state()
        last_at = st.get("last_publish_at", 0) / 1000
        last_str = (
            datetime.fromtimestamp(last_at, TZ).strftime("%Y-%m-%d %H:%M")
            if last_at else "从未发布"
        )
        posts = st.get("posts", [])
        lines = [
            "📮 QQ 动态状态",
            f"启用：{'是' if ENABLED else '否'}",
            f"触发分钟：每小时第 {TRIGGER_MINUTE} 分",
            f"最小间隔：{MIN_INTERVAL_MS // 60000} 分钟",
            f"上次发布：{last_str}",
            f"近 7 天条数：{len(posts)}",
        ]
        if posts:
            lines.append("")
            lines.append("最近动态：")
            for p in posts[-3:]:
                t = datetime.fromtimestamp(p.get("at", 0), TZ).strftime("%m-%d %H:%M")
                lines.append(f"· [{t}] {p.get('text', '')[:50]}")
        yield event.plain_result("\n".join(lines))
