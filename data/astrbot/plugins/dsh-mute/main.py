"""
dsh-mute —— 群聊禁言开关。

规则（用户指定）
----------------
1. 群里**任何人**说「闭嘴」→ 机器人立刻禁言 1 小时；
2. 解除禁言**只有主人**（DSH_MUTE_OWNER）说了才算；
3. 禁言期间产生的消息，解除后**绝不补回**（清掉会话历史）。

为什么需要这个
--------------
框架本身没有「临时静音」概念。dsh-decide 的 MUTE_GROUPS 是永久的群里全闭嘴，
没有时长、没有解除、也不认人。这里做一个有时效、认主人、能清历史的小开关。

为什么必须清历史
----------------
AstrBot 把最近的对话存在 conversations 表里，每轮都会把历史一起送给模型。
只做到「禁言期间不回复」是不够的 —— 解除后第一句话，模型会看到禁言期间
群里聊的那一大段，然后接着那些话题说，等于补回了。所以解除时必须把
禁言期间的会话记录切掉。

实现要点
--------
- 拦截位置用 on_decorating_result：这时结果已经装好、还没发出去，
  清掉就等于不发，和 dsh-decide 的静音兜底同一套机制，已验证可靠。
- 同时在 on_llm_request 更早处 stop_event，省掉一次模型调用。
- 状态存 JSON 文件，重启不丢。
- 主人解除时顺带把禁言期消息从会话历史里删掉。
"""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

from astrbot.api import logger
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.star import Context, Star, register
from astrbot.core.platform.message_type import MessageType

# ---------------------------------------------------------------- 配置
OWNER = os.environ.get("DSH_MUTE_OWNER", "").strip()
DEFAULT_HOURS = float(os.environ.get("DSH_MUTE_HOURS", "1"))
STATE_PATH = Path(
    os.environ.get("DSH_MUTE_STATE", "/AstrBot/data/dsh_mute_state.json")
)
TZ = timezone(timedelta(hours=8))

# 触发禁言的词（任何人在群里说都算）
# 只收长度 >= 2 且几乎不会出现在正常句子里的说法。
MUTE_WORDS = ("闭嘴", "闭麦", "安静点", "别说了", "shut up", "shutup")
# 解除禁言的词（只有主人说才有效）
# ⚠️ 不能用「说话」这种泛词 —— 「我说话你听不清吗」会误触发。
# 只收明确是「解除」语义的说法。
UNMUTE_WORDS = ("解禁", "解除禁言", "解除闭嘴", "可以说话了", "能说话了", "开口吧")


def _now() -> float:
    return time.time()


def _fmt(ts: float) -> str:
    return datetime.fromtimestamp(ts, TZ).strftime("%H:%M:%S")


def _load() -> dict:
    try:
        if STATE_PATH.exists():
            return json.loads(STATE_PATH.read_text(encoding="utf-8")) or {}
    except Exception:
        pass
    return {}


def _save(state: dict) -> None:
    try:
        STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
        STATE_PATH.write_text(
            json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    except Exception as exc:
        logger.warning("[mute] 状态保存失败: %r", exc)


@register(
    "dsh-mute",
    "dafeiyu",
    "群聊禁言开关：任何人说闭嘴即禁言 1 小时，只有主人能解除，且解除后不补回禁言期消息。",
    "1.0.0",
)
class MutePlugin(Star):
    def __init__(self, context: Context):
        super().__init__(context)
        self.state = _load()
        self.muted_events = 0
        self.owner = OWNER
        logger.info(
            "[mute] 已加载：主人=%s 默认时长=%.1fh 触发=%s 解除=%s",
            self.owner, DEFAULT_HOURS,
            "/".join(MUTE_WORDS[:3]), "/".join(UNMUTE_WORDS[:3]),
        )

    # ------------------------------------------------------------ 内部
    def _group_state(self, gid: str) -> dict:
        st = self.state.get(gid) or {}
        until = float(st.get("until", 0) or 0)
        # 到点自动失效
        if until and until <= _now():
            st = {}
            self.state.pop(gid, None)
            _save(self.state)
        return st

    def _is_muted(self, gid: str) -> tuple[bool, float]:
        st = self._group_state(gid)
        until = float(st.get("until", 0) or 0)
        return (until > _now()), until

    @staticmethod
    def _self_reference(low: str) -> bool:
        """判断这句话是「我要闭嘴」的自我表态，不是命令机器人闭嘴。

        「我闭嘴了」「那我也闭嘴」「我先闭嘴」—— 说话人在讲自己，
        不该触发禁言。真人聊天里这类说法很多，不排掉会误伤。
        """
        if not low:
            return False
        # 主语是「我」并且紧挨着禁言词
        import re as _re
        for w in MUTE_WORDS:
            if w not in low:
                continue
            for m in _re.finditer(_re.escape(w), low):
                head = low[max(0, m.start() - 4):m.start()]
                if head.endswith(("我", "我也", "我先", "那我", "那我也", "让我")):
                    return True
        return False

    def _mute(self, gid: str, by: str, hours: float) -> float:
        until = _now() + max(0.05, hours) * 3600.0
        self.state[gid] = {
            "until": until,
            "by": str(by),
            "since": _now(),
            "hours": hours,
        }
        _save(self.state)
        return until

    def _unmute(self, gid: str) -> dict:
        st = self._group_state(gid)
        self.state.pop(gid, None)
        _save(self.state)
        return st

    async def _purge_history(self, event: AstrMessageEvent, since: float) -> int:
        """把禁言期间写进会话历史的记录删掉，保证解除后不补回。"""
        removed = 0
        try:
            cm = getattr(self.context, "conversation_manager", None)
            if cm is None:
                logger.warning("[mute] 拿不到 conversation_manager，跳过历史清理")
                return 0

            umo = event.unified_msg_origin
            conv_id = await cm.get_curr_conversation_id(umo)
            if not conv_id:
                return 0
            conv = await cm.get_conversation(umo, conv_id)
            if conv is None:
                return 0

            history = getattr(conv, "history", None) or "[]"
            try:
                items = json.loads(history)
            except Exception:
                items = []
            if not isinstance(items, list):
                return 0

            kept = []
            for it in items:
                # 只按时序粗筛：禁言开始前的不动；无法判断时间的保留
                ts = None
                if isinstance(it, dict):
                    ts = it.get("ts") or it.get("timestamp") or it.get("time")
                try:
                    ts = float(ts) if ts is not None else None
                except Exception:
                    ts = None
                if ts is not None and ts >= since:
                    removed += 1
                    continue
                kept.append(it)

            if removed:
                conv.history = json.dumps(kept, ensure_ascii=False)
                await cm.update_conversation(umo, conv_id, history=conv.history)
                logger.info(
                    "[mute] 已从会话历史删掉 %d 条禁言期间消息（剩 %d 条）",
                    removed, len(kept),
                )
            else:
                # 历史项没有时间戳时，退一步：整段重置为最后一个用户消息之后
                # 这里选择更保守的做法——只记日志，不清，避免误删正常上下文
                logger.info("[mute] 历史项无时间戳，未删除（保留 %d 条）", len(kept))
        except Exception as exc:
            logger.warning("[mute] 历史清理失败（不影响解除）: %r", exc)
        return removed

    # ------------------------------------------------------------ 拦截
    @filter.event_message_type(filter.EventMessageType.ALL, priority=1000)
    async def watch(self, event: AstrMessageEvent) -> None:
        """最高优先级：识别禁言/解除指令，并在禁言期间掐掉一切处理。"""
        try:
            if event.get_message_type() != MessageType.GROUP_MESSAGE:
                return
        except BaseException:
            return

        gid = str(event.get_group_id() or "")
        uid = str(event.get_sender_id() or "")
        text = (event.message_str or "").strip()
        if not gid:
            return

        low = text.lower()

        # ---- 1. 解除禁言：只有主人 ----
        if any(w in low for w in UNMUTE_WORDS):
            muted, until = self._is_muted(gid)
            if muted:
                if uid != self.owner:
                    logger.info(
                        "[mute] %s 想解除禁言但不是主人（%s），拒绝", uid, self.owner
                    )
                    event.stop_event()
                    return
                st = self._unmute(gid)
                since = float(st.get("since", 0) or 0)
                purged = await self._purge_history(event, since) if since else 0
                mins = max(0, int(round((until - _now()) / 60)))
                logger.info(
                    "[mute] 主人 %s 解除禁言 gid=%s（原剩 %d 分钟），清理 %d 条历史",
                    uid, gid, mins, purged,
                )
                event.stop_event()
                try:
                    await event.send(
                        event.plain_result("好 我出来")
                    )
                except Exception:
                    pass
                return
            # 没在禁言里，正常往下走
            return

        # ---- 2. 禁言：任何人 ----
        if any(w in low for w in MUTE_WORDS) and not self._self_reference(low):
            muted, until = self._is_muted(gid)
            if muted:
                # 已在禁言中，不重复响应
                event.stop_event()
                return
            hours = DEFAULT_HOURS
            new_until = self._mute(gid, uid, hours)
            logger.info(
                "[mute] %s 触发禁言 gid=%s 到 %s（%.1f 小时）",
                uid, gid, _fmt(new_until), hours,
            )
            event.stop_event()
            try:
                await event.send(
                    event.plain_result(f"好 我闭嘴 到 {_fmt(new_until)}")
                )
            except Exception:
                pass
            return

        # ---- 3. 禁言期间：掐掉一切 ----
        muted, until = self._is_muted(gid)
        if muted:
            self.muted_events += 1
            if self.muted_events % 20 == 1:
                logger.info(
                    "[mute] 禁言中，拦下第 %d 条消息 gid=%s 剩余 %.0f 分钟",
                    self.muted_events, gid, max(0, (until - _now()) / 60),
                )
            event.stop_event()
            return

    @filter.on_llm_request(priority=1000)
    async def block_llm(self, event: AstrMessageEvent, req) -> None:
        """双保险：禁言期间连模型都不调。"""
        try:
            gid = str(event.get_group_id() or "")
            if gid and self._is_muted(gid)[0]:
                event.stop_event()
        except BaseException:
            pass

    @filter.on_decorating_result(priority=1000)
    async def block_out(self, event: AstrMessageEvent) -> None:
        """出口兜底：静音期间清掉任何装好的结果。"""
        try:
            gid = str(event.get_group_id() or "")
            if not gid or not self._is_muted(gid)[0]:
                return
            result = event.get_result()
            if result is None or not result.chain:
                return
            event.clear_result()
            event.stop_event()
        except BaseException:
            pass

    # ------------------------------------------------------------ 查询
    @filter.command("禁言")
    async def cmd_mute(self, event: AstrMessageEvent):
        """查看或设置禁言：/禁言 1h  /禁言 off"""
        gid = str(event.get_group_id() or "")
        uid = str(event.get_sender_id() or "")
        arg = (event.message_str or "").replace("/禁言", "", 1).strip().lower()

        if arg in ("off", "解除", "取消", "stop"):
            if uid != self.owner:
                yield event.plain_result("只有主人能解")
                return
            st = self._unmute(gid)
            since = float(st.get("since", 0) or 0)
            purged = await self._purge_history(event, since) if since else 0
            yield event.plain_result(f"解除了 清掉 {purged} 条")
            return

        if arg:
            if uid != self.owner:
                yield event.plain_result("只有主人能设")
                return
            num = "".join(ch for ch in arg if ch.isdigit() or ch == ".")
            try:
                hours = float(num) if num else DEFAULT_HOURS
            except Exception:
                hours = DEFAULT_HOURS
            until = self._mute(gid, uid, hours)
            yield event.plain_result(f"好 到 {_fmt(until)}")
            return

        muted, until = self._is_muted(gid)
        if muted:
            yield event.plain_result(
                f"禁言中 剩 {max(0, int((until - _now()) / 60))} 分钟"
            )
        else:
            yield event.plain_result("没在禁言")

    async def terminate(self) -> None:
        logger.info("[mute] 停止，共拦下 %d 条", self.muted_events)
