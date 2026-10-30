# -*- coding: utf-8 -*-
"""补丁 8：改用「按位置对齐」判定表情包。

问题（实测 2026-10-18 19:57）：
    [stealdbg] types=['ComponentType.Image'] imgs=1 flags=[False]
表情包明明被识别成图片了，但 is_sticker 判成 False。

根因：
    raw_message 里 QQ 给的是原始文件名：file=AB7A0D8CACE0299E3762506A74AA612B.jpg
    而框架落盘后组件上的 file 是：media_image_20261018114307597_ce3a.gif
    两者毫无关系 —— 靠文件名匹配永远失败。

正确做法：
    同一条消息里，raw_message 的 CQ:image 顺序 与 event.message 的
    Image 组件顺序 是一一对应的。按序号取 sub_type 即可。
"""
import sys

P = '/AstrBot/data/plugins/dsh-steal/main.py'
src = open(P, encoding='utf-8').read()
orig = src

OLD_START = 'def _sticker_flags_from_raw(event) -> set[str]:'
OLD_END = 'def _extract_images(event: AstrMessageEvent) -> list[dict]:'
i0 = src.find(OLD_START)
i1 = src.find(OLD_END)
if i0 < 0 or i1 < 0 or i1 <= i0:
    print('ANCHOR MISS'); sys.exit(1)

NEW_FUNCS = '''def _raw_image_subtypes(event) -> list[int]:
    """按顺序返回 raw_message 里每个 CQ:image 的 sub_type。

    实测 raw_message（2026-10-18）：
        表情包   [CQ:image,summary=&#91;动画表情&#93;,file=AB7A...jpg,sub_type=1,...]
        普通图片 [CQ:image,summary=,file=5D25...jpg,sub_type=0,...]

    ⚠ 不能用文件名去和组件上的 file 对齐 —— 框架落盘后改名为
    media_image_xxx.gif，和 QQ 原始名 AB7A...jpg 完全无关（踩过）。
    同一条消息里 CQ 码顺序与 event.message 的 Image 组件顺序一致，
    所以按序号取即可。
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
            # 没有 sub_type 字段时退回 summary 判断
            if "动画表情" in body or "%E5%8A%A8%E7%94%BB" in body:
                subs.append(1)
            else:
                subs.append(0)
    except BaseException:
        pass
    return subs


def _is_sticker_by_index(idx: int, subs: list[int], seg) -> bool:
    """第 idx 个图片段是不是表情包。

    优先用 raw 里对齐到的 sub_type（最可靠）；
    raw 拿不到时退回组件自身字段（框架通常已经丢掉 sub_type，
    所以这时按「判否」处理 —— 宁可漏收，也不把照片存进表情库）。
    """
    try:
        if 0 <= idx < len(subs):
            return subs[idx] == 1
    except BaseException:
        pass
    return _is_sticker_seg(seg)


'''

src = src[:i0] + NEW_FUNCS + src[i1:]

# --- 改 _extract_images：用序号判定，替换 sticker_keys ---
old_init = '''    out: list[dict] = []
    sticker_keys = _sticker_flags_from_raw(event)
    try:'''
new_init = '''    out: list[dict] = []
    subs = _raw_image_subtypes(event)
    img_idx = -1
    try:'''
if old_init not in src:
    print('INIT MISS'); sys.exit(1)
src = src.replace(old_init, new_init, 1)

# 在 out.append 前累加 img_idx 并用它判定
old_append = '''            out.append({
                "fid": fid,
                "url": url,
                "local": local,
                "is_sticker": _is_sticker(fid, seg, sticker_keys, local),
            })'''
new_append = '''            img_idx += 1
            out.append({
                "fid": fid,
                "url": url,
                "local": local,
                "is_sticker": _is_sticker_by_index(img_idx, subs, seg),
            })'''
if old_append not in src:
    print('APPEND MISS'); sys.exit(1)
src = src.replace(old_append, new_append, 1)

# 更新 debug 日志，把 subs 也打出来
old_dbg = '''            logger.info("[stealdbg] gid=%s nseg=%d types=%s imgs=%d flags=%s",
                        event.get_group_id(), len(_segs), _types, len(imgs),
                        [it.get("is_sticker") for it in imgs])'''
new_dbg = '''            logger.info("[stealdbg] gid=%s nseg=%d types=%s subs=%s imgs=%d flags=%s",
                        event.get_group_id(), len(_segs), _types,
                        _raw_image_subtypes(event), len(imgs),
                        [it.get("is_sticker") for it in imgs])'''
if old_dbg in src:
    src = src.replace(old_dbg, new_dbg, 1)

open(P, 'w', encoding='utf-8').write(src)
print('patch8 OK, changed %d bytes' % (len(src) - len(orig)))
