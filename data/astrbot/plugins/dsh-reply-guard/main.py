"""AstrBot 插件：回复节流与陈旧消息拦截

两个需求，都落在「回复出口」，与具体功能插件无关：
  1. 普通文字一分钟最多 10 条 —— 连续追问时不刷屏。
  2. 不回超过 10 句话之前的老消息 —— 群里消息堆着时，模型容易捡起
     十几句前的话题作答，看起来像「突然插话 / 答非所问」。

实现取舍（都踩过点）：
  - 限流只数非命令的文字回复。命令回执（/唱歌状态、/歌单）是有意交互，
    被限流挡住只会让人觉得"工具坏了"；限流要挡的是"话太多"。
  - 滑动窗口 60s，不用固定分钟桶：固定桶会在 :59 和 :00 连发 20 条，
    达不到「一分钟 10 条」的效果。
  - 主人默认豁免限流（DSH_GUARD_OWNER_BYPASS=1）。
  - 陈旧判定只在「有明显积压」时动手，并且 @ / 点名永远放行：
    用户可能刚回来说话，只是群里半天没人理，此时不能误拦。
  - 拦截用 event.stop_event() 静默丢弃，不往群里发"我不回"的提示
    （那种提示本身才是刷屏）。

注意：EventMessageType 实测只有 GROUP_MESSAGE / PRIVATE_MESSAGE /
OTHER_MESSAGE，没有 ALL，所以监听器要分开注册或用一个真正的全集。
本插件用 on_llm_request 做编号，不需要 message_type 过滤。
"""

import os
import re
import time
from collections import deque

from astrbot.api import star
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.core import logger

# ---------------------------------------------------------------- 配置
OWNER_ID = os.environ.get("DSH_SING_OWNER", "").strip()

RATE_WINDOW = int(os.environ.get("DSH_GUARD_RATE_WINDOW", "60"))   # 秒
RATE_MAX = int(os.environ.get("DSH_GUARD_RATE_MAX", "10"))         # 窗口内最多几条
OWNER_BYPASS_RATE = os.environ.get("DSH_GUARD_OWNER_BYPASS", "1") == "1"

STALE_LAG = int(os.environ.get("DSH_GUARD_STALE_LAG", "10"))       # 超过几句话不回
STALE_ENABLED = os.environ.get("DSH_GUARD_STALE", "1") == "1"

# 命令类前缀：这些已发起的交互，回复不受限流约束
_CMD_RE = re.compile(r"^\s*(?:@\S+\s*)?/")

# 每个会话的发文窗口
_WINDOW: dict[str, deque] = {}
# 会话 -> 累计处理过的消息条数
_SEQ: dict[str, int] = {}
# 会话 -> 上次真正回复时对应的序号
_LAST_REPLY: dict[str, int] = {}
# 会话 -> 上次真正回复的时间
_LAST_REPLY_TS: dict[str, float] = {}
# 会话 -> 该会话最后一条消息的时间（判断"是不是很久没人说话"）
_LAST_MSG_TS: dict[str, float] = {}


def _umo(event) -> str:
    return getattr(event, "unified_msg_origin", "") or "global"


def _is_owner(event) -> bool:
    return str(event.get_sender_id()) == OWNER_ID


def _named(text: str) -> bool:
    """是否点名了机器人（@、昵称、QQ 号）。"""
    t = text or ""
    if "@" in t:
        return True
    for nick in ("小鲸鱼", "鲸鱼", "肥鱼", "大肥鱼"):
        if nick in t:
            return True
    self_id = os.environ.get("DSH_SELF_ID", "")
    if self_id and self_id in t:
        return True
    return False


# ---------------------------------------------------------------- 限流
def _rate_take(umo: str) -> bool:
    """滑动窗口限流：允许就占一格并返回 True。"""
    now = time.time()
    win = _WINDOW.setdefault(umo, deque())
    while win and now - win[0] > RATE_WINDOW:
        win.popleft()
    if len(win) >= RATE_MAX:
        return False
    win.append(now)
    return True


def _rate_left(umo: str) -> int:
    now = time.time()
    win = _WINDOW.get(umo, deque())
    alive = [t for t in win if now - t <= RATE_WINDOW]
    return max(0, RATE_MAX - len(alive))


# ---------------------------------------------------------------- 插件
class ReplyGuardPlugin(star.Star):
    """回复节流 + 陈旧消息拦截"""

    def __init__(self, context, config=None):
        super().__init__(context, config)
        logger.info(
            "[guard] 已加载：限流 %d条/%ds（主人豁免=%s）｜陈旧拦截 %s（滞后>%d句）",
            RATE_MAX, RATE_WINDOW, OWNER_BYPASS_RATE,
            "开" if STALE_ENABLED else "关", STALE_LAG,
        )

    # -------- 请求阶段：编号 + 陈旧判定 --------
    @filter.on_llm_request()
    async def on_request(self, event: AstrMessageEvent, req) -> None:
        """每条要进 LLM 的消息：记序号、判陈旧。"""
        try:
            umo = _umo(event)
            # 记序号与时间
            _SEQ[umo] = _SEQ.get(umo, 0) + 1
            cur = _SEQ[umo]
            now = time.time()
            _LAST_MSG_TS[umo] = now

            if not STALE_ENABLED:
                _LAST_REPLY[umo] = cur
                return

            text = (event.message_str or "")
            last = _LAST_REPLY.get(umo, 0)
            last_ts = _LAST_REPLY_TS.get(umo, 0.0)

            # 没有任何历史回复 → 不用判（第一句必须回）
            if not last:
                _LAST_REPLY[umo] = cur
                _LAST_REPLY_TS[umo] = now
                return

            lag = cur - last                       # 距上次回复过了几句
            idle = now - last_ts                   # 距上次回复过了多久

            # 放行条件（任一即可）：
            #   ① 点名/@ —— 明确在找我
            #   ② 积压不深（lag <= STALE_LAG）—— 正常对话
            #   ③ 已经空闲很久（idle > 10 分钟）—— 可能是新会话开场
            if _named(text) or lag <= STALE_LAG or idle > 600:
                _LAST_REPLY[umo] = cur
                _LAST_REPLY_TS[umo] = now
                return

            # 到这儿说明：没人点名 + 中间积压了 >STALE_LAG 句 + 最近还很活跃
            # 这是典型的"捡起十几句前的话题"，静默丢弃。
            logger.info(
                "[guard] 滞后 %d 句（>%d），本次不接话：%.40s",
                lag, STALE_LAG, text,
            )
            _LAST_REPLY[umo] = cur
            _LAST_REPLY_TS[umo] = now
            try:
                event.stop_event()
            except Exception:
                pass
        except BaseException as exc:
            logger.warning("[guard] 陈旧判定失败（放行）：%s", exc)

    # -------- 回复阶段：限流 --------
    @filter.on_llm_response()
    async def throttle(self, event: AstrMessageEvent, response=None) -> None:
        """窗口内超过 N 条时，把多出来的这条清空（不发出去）。"""
        try:
            text = (getattr(response, "completion_text", "") or "").strip()
            if not text:
                return
            # 命令回执不限流
            if _CMD_RE.match(event.message_str or ""):
                return
            if OWNER_BYPASS_RATE and _is_owner(event):
                return

            umo = _umo(event)
            if _rate_take(umo):
                return

            logger.info(
                "[guard] 限流拦下一条（%ds 内已 %d 条）：%.40s",
                RATE_WINDOW, RATE_MAX, text,
            )
            try:
                response.completion_text = ""
            except Exception:
                try:
                    response._completion_text = ""
                except Exception:
                    pass
        except BaseException as exc:
            logger.warning("[guard] 限流判断失败（放行）：%s", exc)

    # -------- /限流状态 --------
    @filter.regex(r"^\s*(?:@\S+\s*)?/?(?:限流状态|节流状态)\s*$")
    async def cmd_status(self, event: AstrMessageEvent):
        """查看当前限流与陈旧拦截配置"""
        umo = _umo(event)
        cur = _SEQ.get(umo, 0)
        last = _LAST_REPLY.get(umo, 0)
        lines = ["🚦 回复节流状态", ""]
        lines.append(f"限流：{RATE_MAX} 条 / {RATE_WINDOW} 秒（滑动窗口）")
        lines.append(f"本会话剩余额度：{_rate_left(umo)} 条")
        lines.append(f"主人豁免限流：{'是' if OWNER_BYPASS_RATE else '否'}")
        lines.append(f"陈旧拦截：{'开' if STALE_ENABLED else '关'}"
                     f"（滞后 > {STALE_LAG} 句且未点名时不接话）")
        lines.append(f"本会话已处理 {cur} 条，上次回应在第 {last} 条"
                     + (f"（滞后 {cur-last}）" if last else ""))
        lines.append("")
        lines.append("点名/@、空闲超过 10 分钟、命令回复都不受上述限制")
        event.set_result(event.plain_result("\n".join(lines)))
