"""
dsh-awake —— 让机器人在群里能「不 @ 也说话」。

问题根因
--------
AstrBot 的 ProcessStage 只在 `event.is_at_or_wake_command` 为真时才调 LLM：

    if (not event._has_send_oper
        and event.is_at_or_wake_command     # ← 只有 被@ / 被回复 / 以 / 开头 才为真
        and not event.call_llm):

群里普通闲聊这个标志永远是 False，于是消息能进插件、却永远走不到模型。
表现就是「不 @ 它，一句都不说」。

本插件做什么
------------
在 WakingCheckStage 跑完之后、ProcessStage 判定之前，把群消息的这个标志补上，
让普通群消息也能走到 LLM —— 但仍然要过 dsh-decide 那道「该不该开口」的判断，
所以不会变成有问必答的复读机。

为什么不能更早改
----------------
WakingCheckStage 自己会用 is_wake 决定要不要 stop_event，
在那个阶段之前改标志没有意义；必须等它跑完。

指令保护
--------
以 / 或 ! 开头的消息不动它 —— 指令本来就该走指令路径，由 dsh-acl 管权限。
"""
from __future__ import annotations

import os

from astrbot.api import logger
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.star import Context, Star
from astrbot.core.platform.message_type import MessageType

ENABLED = os.environ.get("DSH_AWAKE", "1").strip().lower() not in {"0", "false", "off", "no"}
GROUPS = {
    g.strip()
    for g in os.environ.get("DSH_AWAKE_GROUPS", "").split(",")
    if g.strip()
}


class AwakePlugin(Star):
    def __init__(self, context: Context):
        super().__init__(context)
        self.seen = 0
        self.forced = 0
        self.skipped = 0
        logger.info(
            "[awake] 已加载：%s 群=%s（不 @ 也能说话）",
            "开" if ENABLED else "关",
            ",".join(sorted(GROUPS)) or "全部",
        )

    # priority 越大越先执行。WakingCheckStage 已经跑完，
    # 这里把标志补上，供 ProcessStage 判定。
    @filter.event_message_type(filter.EventMessageType.ALL, priority=-100)
    async def force_wake(self, event: AstrMessageEvent) -> None:
        if not ENABLED:
            return

        # 只处理群聊。私聊本来就不需要唤醒词。
        try:
            if event.get_message_type() != MessageType.GROUP_MESSAGE:
                return
        except BaseException:
            return

        gid = str(event.get_group_id() or "")
        if GROUPS and gid not in GROUPS:
            return

        # 指令不动：让 dsh-acl 它们按原路走。
        msg = (event.message_str or "").strip()
        if msg.startswith(("/", "／", "!", "！")):
            self.skipped += 1
            return

        # 已经被 @ / 被回复过的消息，框架已经处理好了，不碰。
        if bool(getattr(event, "is_at_or_wake_command", False)):
            return

        try:
            event.is_at_or_wake_command = True
            event.is_wake = True
            self.forced += 1
            self.seen += 1
            if self.seen % 50 == 1:
                logger.info(
                    "[awake] 已放行 %d 条普通群消息（跳指令 %d）gid=%s",
                    self.forced, self.skipped, gid,
                )
        except BaseException as exc:
            logger.warning("[awake] 放行失败（不影响原流程）: %r", exc)

    async def terminate(self) -> None:
        logger.info("[awake] 停止：放行 %d 条", self.forced)
