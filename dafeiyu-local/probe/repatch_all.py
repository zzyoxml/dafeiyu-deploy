# -*- coding: utf-8 -*-
"""dsh-steal 完整补丁集（重打版 2026-10-18 20:27）

背景：之前分 9 次打补丁，中间 /tmp 被清理导致 1-8 丢失，
只剩补丁 9。本脚本从 .bak-sticker 原始文件重新施加全部改动，
每步都校验锚点，失败即中止（不留半成品）。

补丁清单：
  P1  新增 _is_sticker_seg / _raw_image_subtypes / _is_sticker_by_index
      —— 用 raw_message 里 CQ:image 的顺序对齐 sub_type，
         区分表情包(sub_type=1) 与 普通照片(sub_type=0)
  P2  _extract_images 返回 is_sticker 字段
  P3  observe 里跳过非表情包（skip_photo 计数）
  P4  MIN_COUNT 默认 3 -> 1（用户：发三次一次就可以）
  P5  CAPTION_PROMPT 增加「有没有梗」判断，无梗回 NO
  P6  模型回 NO 时拒绝入库（cap_no_interest 计数）
  P7  _select_for_reply 放宽到「语气相近即可」，并记录模型原始回答；
      调用异常时随机兜底而不是彻底不发
"""
import sys

P = '/AstrBot/data/plugins/dsh-steal/main.py'
BAK = P + '.bak-sticker'
src = open(BAK, encoding='utf-8').read()
steps = []


def sub(tag, old, new, count=1):
    global src
    if old not in src:
        print('FAIL %s: anchor not found' % tag)
        print('     wanted: %r' % old[:90])
        sys.exit(1)
    src = src.replace(old, new, count)
    steps.append(tag)


# ---------------- P1: 三个新函数 ----------------
P1_NEW = '''def _is_sticker_seg(seg) -> bool:
    """这个图片段是不是「表情包」而不是普通照片/截图。

    实测 OneBot 原始消息（2026-10-18）：
        表情包  {"summary": "[动画表情]", "file": "AB7A...jpg", "sub_type": 1}
        普通图片 {"summary": "",            "file": "5D25...jpg", "sub_type": 0}

    框架的 astrbot Image 组件只保留 file(本地路径)/url，sub_type 与 summary
    会被丢掉，所以主判定走 _raw_image_subtypes（按 CQ 码顺序对齐）。
    这里是拿不到 raw 时的退化路径 —— 保守判否，宁可不收，
    也不能把群友的照片存进表情库。
    """
    try:
        d = {}
        if isinstance(seg, dict):
            d = seg.get("data") or {}
        else:
            try:
                d = seg.toDict().get("data") or {}
            except BaseException:
                d = {}
        st = d.get("sub_type", None)
        sm = str(d.get("summary") or "")
        if st is not None:
            try:
                if int(st) == 1:
                    return True
                if int(st) == 0:
                    return False
            except BaseException:
                pass
        if "表情" in sm:
            return True
    except BaseException:
        pass
    return False


def _raw_image_subtypes(event) -> list[int]:
    """按顺序返回 raw_message 里每个 CQ:image 的 sub_type。

    实测 raw_message：
        表情包   [CQ:image,summary=&#91;动画表情&#93;,file=AB7A...jpg,sub_type=1,...]
        普通图片 [CQ:image,summary=,file=5D25...jpg,sub_type=0,...]

    ⚠ 不能用文件名去和组件上的 file 对齐 —— 框架落盘后改名为
    media_image_xxx.gif，和 QQ 原始名 AB7A...jpg 完全无关（踩过一次，
    表现是 flags 永远 False）。同一条消息里 CQ 码顺序与 event.message
    的 Image 组件顺序一致，按序号取即可。
    """
    subs: list[int] = []
    try:
        raw = getattr(getattr(event, "message_obj", None), "raw_message", None)
        if not isinstance(raw, str):
            raw = str(raw or "")
        for m in re.finditer(r"\\[CQ:image,([^\\]]*)\\]", raw):
            body = m.group(1)
            sm = re.search(r"sub_type=(\\d+)", body)
            if sm:
                try:
                    subs.append(int(sm.group(1)))
                    continue
                except BaseException:
                    pass
            if "动画表情" in body or "%E5%8A%A8%E7%94%BB" in body:
                subs.append(1)
            else:
                subs.append(0)
    except BaseException:
        pass
    return subs


def _is_sticker_by_index(idx: int, subs: list[int], seg) -> bool:
    """第 idx 个图片段是不是表情包（优先用 raw 对齐的 sub_type）。"""
    try:
        if 0 <= idx < len(subs):
            return subs[idx] == 1
    except BaseException:
        pass
    return _is_sticker_seg(seg)


'''
P1_ANCHOR = 'def _extract_images(event: AstrMessageEvent) -> list[dict]:'
sub('P1 新增识别函数', P1_ANCHOR, P1_NEW + P1_ANCHOR)

# ---------------- P2: _extract_images 返回 is_sticker ----------------
sub('P2 初始化 subs/img_idx',
    '''    out: list[dict] = []
    try:
        msg = event.message_obj''',
    '''    out: list[dict] = []
    subs = _raw_image_subtypes(event)
    img_idx = -1
    try:
        msg = event.message_obj''')

sub('P2 append 加 is_sticker',
    '''            out.append({"fid": fid, "url": url, "local": local})''',
    '''            img_idx += 1
            out.append({
                "fid": fid,
                "url": url,
                "local": local,
                "is_sticker": _is_sticker_by_index(img_idx, subs, seg),
            })''')

# ---------------- P3: observe 跳过非表情包 ----------------
sub('P3 observe 过滤照片',
    '''            _stat["seen"] += 1
            for it in imgs:
                n = _count_bump(it["fid"], it["url"], it.get("local") or "")''',
    '''            _stat["seen"] += 1
            for it in imgs:
                # 只要表情包（QQ sub_type=1 / [动画表情]）。
                # 群友的照片、截图、资料图一律不进库 —— 用户明确要求
                # 「不是照片啊」，且表情库混进照片会让挑选变成瞎发图。
                if not it.get("is_sticker"):
                    _stat["skip_photo"] = _stat.get("skip_photo", 0) + 1
                    continue
                n = _count_bump(it["fid"], it["url"], it.get("local") or "")''')

# ---------------- P4: 阈值 3 -> 1 ----------------
sub('P4 阈值改 1',
    'MIN_COUNT = max(2, int(os.environ.get("DSH_STEAL_MIN_COUNT", "3")))',
    '# 用户钦定（2026-10-18）：「发三次一次就可以」—— 不再等同一张图\n'
    '# 反复出现，看到能看懂意思的表情包就收；靠 stickers 表去重。\n'
    'MIN_COUNT = max(1, int(os.environ.get("DSH_STEAL_MIN_COUNT", "1")))')

# ---------------- P5: prompt 加「有没有梗」 ----------------
OLD_PROMPT = '''CAPTION_PROMPT = os.environ.get(
    "DSH_STEAL_PROMPT",
    "这是群里常见的一张表情包/梗图。用中文30字内说它表达什么含义、"
    "适合什么场合用。若内容不适宜公开传播（色情/暴力/政治/辱骂），"
    "只回两个字：不宜。",
)
CAPTION_PROMPT_GIF = os.environ.get(
    "DSH_STEAL_PROMPT_GIF",
    "这是同一个动图的{n}帧（按时间从左到右）。这是群里常见的一张GIF表情包。"
    "用中文30字内说它表达什么含义、适合什么场合用。"
    "若内容不适宜公开传播（色情/暴力/政治/辱骂），只回两个字：不宜。",
)'''

NEW_PROMPT = '''# 用户钦定（2026-10-18）：「不是照片啊」「最好有意思一点的」。
# 收图三道关：① QQ 层面是表情包（sub_type=1，_extract_images 已过滤照片）
#              ② 能看懂含义（模型给出 caption）
#              ③ **有梗/有情绪表达价值**（这一条以前没有，纯文字截图也会入库）
# 模型三种输出区分：NO=不值得收，不宜=不能公开传播，其他=可用含义。
CAPTION_PROMPT = os.environ.get(
    "DSH_STEAL_PROMPT",
    "这是一张群聊表情包。请判断两件事：\\n"
    "1) 它有没有表情包的「梗」——能不能替人表达某种情绪、态度或反应"
    "（比如无语、得意、摆烂、催促、撒娇、嘲讽、震惊）。"
    "如果它只是普通照片、聊天截图、通知图、资料图、风景图、"
    "纯文字图片、或看不出任何可复用的情绪表达，只回两个字：NO。\\n"
    "2) 如果内容不适宜公开传播（色情/暴力/政治/辱骂），只回两个字：不宜。\\n"
    "3) 否则用中文 30 字内说清它表达什么情绪、适合什么场合用。"
    "直接给答案，不要解释你在做什么。",
)
CAPTION_PROMPT_GIF = os.environ.get(
    "DSH_STEAL_PROMPT_GIF",
    "这是同一个动图的{n}帧（按时间从左到右）。这是一张群聊GIF表情包。"
    "请判断两件事：\\n"
    "1) 它有没有表情包的「梗」——能不能替人表达某种情绪、态度或反应"
    "（比如无语、得意、摆烂、催促、撒娇、嘲讽、震惊）。"
    "如果只是普通录屏、通知动画、看不出任何可复用的情绪表达，"
    "只回两个字：NO。\\n"
    "2) 如果内容不适宜公开传播（色情/暴力/政治/辱骂），只回两个字：不宜。\\n"
    "3) 否则用中文 30 字内说清它表达什么情绪、适合什么场合用。"
    "直接给答案，不要解释你在做什么。",
)'''
sub('P5 prompt 加有没有梗', OLD_PROMPT, NEW_PROMPT)

# ---------------- P6: NO 不入库 ----------------
sub('P6 NO 拒绝入库',
    '''            cap = " ".join(cap.split())[:120]
            if "不宜" in cap:
                _stat["cap_unfit"] += 1
                logger.info("[steal] 内容不适宜公开，不偷：%s (%s)",
                            fid[:20], cap[:20])
                return''',
    '''            cap = " ".join(cap.split())[:120]
            if "不宜" in cap:
                _stat["cap_unfit"] += 1
                logger.info("[steal] 内容不适宜公开，不偷：%s (%s)",
                            fid[:20], cap[:20])
                return
            # 「没意思」也挡掉 —— 用户要求只收有梗的。纯文字截图/通知图/
            # 普通风景这类识别得出来但不值得用的，模型会回 NO。
            _up = cap.upper().replace(" ", "")
            if _up == "NO" or _up.startswith("NO.") or _up.startswith("NO，"):
                _stat["cap_no_interest"] = _stat.get("cap_no_interest", 0) + 1
                logger.info("[steal] 没有梗/没表达价值，不偷：%s", fid[:20])
                return''')

# ---------------- P7: 选图放宽 ----------------
OLD_SEL = '''        prompt = (
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

NEW_SEL = '''        prompt = (
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
            logger.info("[steal] 选图结果=%r（候选 %d 张）",
                        (answer or "")[:40], len(candidates))
            m = re.search(r"\\d+", answer)
            idx = int(m.group(0)) if m else 0
            if 1 <= idx <= len(candidates):
                return candidates[idx - 1][0]
            logger.info("[steal] 模型认为没有合适表情（回 %r）",
                        (answer or "")[:20])
        except BaseException as exc:
            # 调用本身出错（超时/无 provider）不该让功能彻底消失：
            # 随机取一张，最多不太贴切，胜过从来不发表情包。
            logger.warning("[steal] 自动选图失败，随机兜底：%s", exc)
            try:
                return candidates[0][0]
            except BaseException:
                return ""
        return ""'''
sub('P7 选图放宽', OLD_SEL, NEW_SEL)

open(P, 'w', encoding='utf-8').write(src)
import ast
ast.parse(src)
print('全部补丁 OK：%s' % ' / '.join(steps))
print('文件大小 %d 字节（原始 %d）' % (len(src), len(open(BAK, encoding='utf-8').read())))
