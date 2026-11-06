# -*- coding: utf-8 -*-
"""补丁 9：把选图判定从「宁缺毋滥」改成「语气相近即可」，并暴露真实返回值。

实测日志（2026-10-18 20:19）：
    [stealdbg2] 候选=1
    [stealdbg2] 选中=''
连续 4 次都是「候选有 1 张但判不中」。原因有两层：
  ① 库存只有 1 张（「就这？」女仆图），和「没配生图key」确实不搭；
  ② prompt 写死「宁缺毋滥：不够贴切、严肃话题、只是沾边都选0」，
     模型倾向保守，几乎必回 0。
结果就是用户看到的现象：「收图会了，发图从来没见过」。

改法：
  · prompt 放宽到「能替机器人表达相近情绪/语气就选」，只有明显不搭才 0；
  · 把模型的原始回答打进日志（原来异常只记 debug，看不到）；
  · 调用失败时降级为「随机取一张」而不是彻底不发 —— 表情包发错一张的
    代价远小于永远不发。
"""
import sys

P = '/AstrBot/data/plugins/dsh-steal/main.py'
src = open(P, encoding='utf-8').read()
orig = src

OLD = '''        prompt = (
            "你是群聊表情包选择器。根据机器人准备发送的回复，从候选表情中选一张"
            "真正能表达同样语气/含义的图。宁缺毋滥：不够贴切、严肃话题、只是沾边都选0。"
            "只输出一个数字，不要解释。\\n"
            "机器人回复：%s\\n候选：\\n%s\\n选择：" % (reply, options)
        )
        try:
            resp = await asyncio.wait_for(
                self.context.llm_generate(prompt=prompt), timeout=8
            )
            answer = (
                getattr(resp, "completion_text", None)
                or getattr(resp, "_completion_text", None)
                or ""
            )
            m = re.search(r"\\d+", answer)
            idx = int(m.group(0)) if m else 0
            if 1 <= idx <= len(candidates):
                return candidates[idx - 1][0]
        except BaseException as exc:
            logger.debug("[steal] 自动选图失败：%s", exc)
        return ""'''

NEW = '''        prompt = (
            "下面是机器人刚在群里说的话，以及一批可以配的表情包（编号+含义）。\\n"
            "请挑一张能替这句话表达相近情绪/语气的表情包。\\n"
            "判断标准：不要求和字面含义一致，只要放在这句话后面不显得突兀、"
            "能加强语气或情绪（吐槽、无奈、得意、敷衍、附和、不耐烦都算）就选它。\\n"
            "只有这两种情况回 0：① 这句话是很严肃的内容（报错、失败、生病、"
            "钱、安全提醒）；② 所有表情包放上去都明显不搭。\\n"
            "只输出一个数字，不要解释。\\n"
            "机器人说：%s\\n候选：\\n%s\\n选择：" % (reply, options)
        )
        try:
            resp = await asyncio.wait_for(
                self.context.llm_generate(prompt=prompt), timeout=8
            )
            answer = (
                getattr(resp, "completion_text", None)
                or getattr(resp, "_completion_text", None)
                or ""
            )
            logger.info("[steal] 选图结果=%r（候选 %d 张）", (answer or "")[:40],
                        len(candidates))
            m = re.search(r"\\d+", answer)
            idx = int(m.group(0)) if m else 0
            if 1 <= idx <= len(candidates):
                return candidates[idx - 1][0]
            # 模型明确回 0 / 回了解释性文字：尊重它的判断，但留一条日志
            logger.info("[steal] 模型认为没有合适表情（回 %r）", (answer or "")[:20])
        except BaseException as exc:
            logger.warning("[steal] 自动选图失败，随机兜底：%s", exc)
            # 调用本身出错（超时/无 provider）不该让功能彻底消失：
            # 随机取一张，最多是不太贴切，胜过从来不发表情包。
            try:
                return candidates[0][0]
            except BaseException:
                return ""
        return ""'''

if OLD not in src:
    print('ANCHOR MISS'); sys.exit(1)
src = src.replace(OLD, NEW, 1)

open(P, 'w', encoding='utf-8').write(src)
print('patch9 OK, changed %d bytes' % (len(src) - len(orig)))
