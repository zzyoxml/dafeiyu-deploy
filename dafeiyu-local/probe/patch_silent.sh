#!/bin/bash
set -u
P=/opt/dafeiyu/data/astrbot/plugins/dsh-selfguard/main.py

python3 - "$P" <<'PYEOF'
import re, sys

path = sys.argv[1]
src = open(path, encoding='utf-8').read()

OLD_TAIL = '''            level = 0
            if hit == "自我重复":
                uid = str(event.get_sender_id() or "")
                now = time.time()
                state_key = (gid, uid)
                old_state = self._impatient.get(state_key)
                level = impatient_level(old_state, now)
                reply = choose_impatient_reply(level, old_state.last_reply if old_state else "")
                self._impatient[state_key] = ImpatientState(level, now, reply)
                if len(self._impatient) > 200:
                    cutoff = now - IMPATIENT_RESET
                    self._impatient = {
                        state_key: state for state_key, state in self._impatient.items()
                        if state.last_at >= cutoff
                    }
            else:
                reply = choose_taunt_reply(self._last_taunt_reply)
                self._last_taunt_reply = reply
            try:
                event.set_result(reply)
            except BaseException:
                event.clear_result()
                event.stop_event()
            logger.info(
                "[selfguard] 出口拦下一条（%s）-> %s%s",
                brief, reply, "（不耐烦%d级）" % level if level else "",
            )
'''

NEW_TAIL = '''            # [patch:silent] 2026-11-05 改成静默丢弃，不再塞话术。
            #
            # 原来的做法是把模型的回复整条丢掉，换成一张固定话术表里的句子：
            #   1级 ("又来", "刚说过，别复读", "还问这个啊", "这茬刚聊完")
            #   2级 ("你怎么还在问", "都说过了，烦不烦", "还来？换个话题", ...)
            #   3级 ("不聊这个了", "打住，换一个", "没完了是吧", ...)
            #
            # 群主原话：「禁止机器人回复 如：我这边没看见、还来？、还问这个啊
            # 等 不像正常人的 机械回复」。
            #
            # 这几句的共同毛病不是态度差，是**形状固定**：换个用户、换个话题、
            # 换一天，说出来的还是同一批句子。真人再不耐烦也不会背台词，
            # 顶多不理，或者换个说法把话带过去。所以这里改成彻底不发。
            #
            # 顺带说明：2026-09-12 群主就因为讨厌这类话术关掉了
            # DSH_SELFGUARD_REPEAT，但当时只关了长句重复那条通道，
            # 这段 IMPATIENT 递进是另一条路，漏掉了。
            #
            # 现在的行为：命中重复 → stop_event() 静默丢弃，群里看不到任何东西。
            # 想恢复旧行为，把下面两行换成原来的 set_result(reply) 即可。
            if hit == "自我重复":
                uid = str(event.get_sender_id() or "")
                now = time.time()
                state_key = (gid, uid)
                old_state = self._impatient.get(state_key)
                level = impatient_level(old_state, now)
                self._impatient[state_key] = ImpatientState(level, now, "")
                if len(self._impatient) > 200:
                    cutoff = now - IMPATIENT_RESET
                    self._impatient = {
                        state_key: state for state_key, state in self._impatient.items()
                        if state.last_at >= cutoff
                    }
            try:
                event.clear_result()
                event.stop_event()
            except BaseException:
                pass
            logger.info(
                "[selfguard] 出口拦下一条并静默（%s）%s",
                brief, "（不耐烦%d级）" % level if level else "",
            )
'''

if OLD_TAIL not in src:
    print("  [!!] 没找到待替换段落，未改动")
    sys.exit(1)

src = src.replace(OLD_TAIL, NEW_TAIL, 1)
open(path, 'w', encoding='utf-8').write(src)
print("  [OK] 已替换")
PYEOF

echo ""
echo "=== 改造后 380-420 行 ==="
sed -n '380,425p' "$P"

echo ""
echo "=== 语法检查 ==="
docker exec astrbot python3 -m py_compile /AstrBot/data/plugins/dsh-selfguard/main.py 2>&1 && echo "  [OK] 语法通过" || echo "  [!!] 语法错误"
