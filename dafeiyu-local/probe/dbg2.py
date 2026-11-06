# -*- coding: utf-8 -*-
"""诊断：auto_serve (on_llm_response) 到底有没有被调用。"""
import sys

P = '/AstrBot/data/plugins/dsh-steal/main.py'
src = open(P, encoding='utf-8').read()

OLD = '''    @filter.on_llm_response()
    async def auto_serve(self, event: AstrMessageEvent, response: LLMResponse) -> None:
        """日常聊天低频按语义使用偷来的表情；图片独立发送，不附含义文字。"""
        if ('''

NEW = '''    @filter.on_llm_response()
    async def auto_serve(self, event: AstrMessageEvent, response: LLMResponse) -> None:
        """日常聊天低频按语义使用偷来的表情；图片独立发送，不附含义文字。"""
        try:
            logger.info("[stealdbg2] auto_serve CALLED gid=%s mtype=%s text=%r",
                        event.get_group_id(), event.get_message_type(),
                        (getattr(response, "completion_text", "") or "")[:50])
        except BaseException:
            logger.info("[stealdbg2] auto_serve CALLED (log fail)")
        if ('''

if OLD not in src:
    print('MISS'); sys.exit(1)
src = src.replace(OLD, NEW, 1)

# 再在每个早退分支加日志
subs = [
    ('''            if not self._auto_reply_suitable(text):
                _stat["auto_unsuitable"] += 1
                return''',
     '''            if not self._auto_reply_suitable(text):
                _stat["auto_unsuitable"] += 1
                logger.info("[stealdbg2] 不适合配图 len=%d text=%r", len(text), text[:40])
                return'''),
    ('''            if now - _last_auto.get(gid, 0.0) < AUTO_COOLDOWN:
                _stat["auto_cooldown"] += 1
                return''',
     '''            if now - _last_auto.get(gid, 0.0) < AUTO_COOLDOWN:
                _stat["auto_cooldown"] += 1
                logger.info("[stealdbg2] 冷却中 剩%.0fs", AUTO_COOLDOWN - (now - _last_auto.get(gid, 0.0)))
                return'''),
    ('''            if random.random() >= AUTO_RATE:
                return''',
     '''            _r = random.random()
            if _r >= AUTO_RATE:
                logger.info("[stealdbg2] 掷骰未中 %.3f >= %.2f", _r, AUTO_RATE)
                return'''),
    ('''            candidates = self._auto_candidates()
            if not candidates:
                return''',
     '''            candidates = self._auto_candidates()
            logger.info("[stealdbg2] 候选=%d", len(candidates))
            if not candidates:
                return'''),
    ('''            path = await self._select_for_reply(text, candidates)
            if not path:
                return''',
     '''            path = await self._select_for_reply(text, candidates)
            logger.info("[stealdbg2] 选中=%r", path)
            if not path:
                return'''),
]
n = 0
for old, new in subs:
    if old in src:
        src = src.replace(old, new, 1)
        n += 1
    else:
        print('  sub miss:', old[:40])

open(P, 'w', encoding='utf-8').write(src)
print('debug2 ok, %d/%d subs' % (n, len(subs)))
