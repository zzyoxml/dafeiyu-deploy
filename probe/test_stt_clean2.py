#!/bin/bash
# dsh-stt-clean 的离线逻辑回归（9 个场景）
#
# 为什么单独有这个测试：
#   插件第一版写 if 'Singing' in tags，但 tags 存的是完整标签 '<|Singing|>'，
#   集合精确匹配永远 False，前缀从没加上过——肉眼看日志发现不了，必须用断言。
#
# 场景覆盖：唱歌带词 / BGM 带词 / 纯 Singing / 纯 BGM / 正常说话 /
#          纯文字 / 正常长句 / Speech 残留 / 情绪 emoji 保留
"""dsh-stt-clean v1.0.1 离线逻辑验证。"""
import re

TAG_FULL_RE = re.compile(r"<\|([^|]+)\|>")
TAG_RE = re.compile(r"<\|[^|]+\|>")
SINGING_NAMES = {"Singing"}
MUSIC_NAMES = {"BGM", "Applause", "Laughter"}
MUSIC_EMOJI = "🎼"


def clean(raw):
    if "<|" not in raw and MUSIC_EMOJI not in raw:
        return None
    names = set(TAG_FULL_RE.findall(raw))
    text = TAG_RE.sub("", raw).strip()
    if names & SINGING_NAMES:
        prefix = "（对方在唱歌）"
    elif (names & MUSIC_NAMES) or MUSIC_EMOJI in text:
        prefix = "（对方发的是音乐或音效，不是说话）"
    else:
        prefix = ""
    if not text:
        return prefix or "（对方发了一段没有识别出文字的音频）"
    if prefix:
        return f"{prefix}{text}"
    return text


CASES = [
    # 真实场景（从实际日志拿到的）
    ("<|Singing|>不敢轻皮黄颜红萧萧不计俗世傲海笑只身甘迢今朝", "唱歌带词", "（对方在唱歌）"),
    ("🎼노든 방 좋아 와的天지 이 개 느껴겨 지를 유 배워", "BGM 带词", "（对方发的是音乐或音效，不是说话）"),
    ("<|Singing|>", "纯 Singing 无词", "（对方在唱歌）"),
    ("🎼", "纯 BGM", "（对方发的是音乐或音效，不是说话）"),
    # 正常说话不该被改
    ("糖葫芦或者桂花糖藕😊", "正常说话", None),
    ("你好", "纯文字", None),
    ("这段我这边听不清你说的是啥", "正常长句", None),
    # 其它残留标签
    ("<|zh|><|NEUTRAL|><|Speech|><|woitn|>正常", "Speech 残留", "正常"),
    # 情绪 emoji 要保留
    ("今天下午两点多这时候就想来点甜的😊", "带情绪 emoji", None),
]

print(f"{'结果':6} {'场景':16} {'输入':30} -> 输出")
print("=" * 100)
fail = 0
for raw, desc, expect in CASES:
    out = clean(raw)
    if expect is None:
        ok = out is None
        shown = "（不处理）"
    elif expect in ("（对方在唱歌）", "（对方发的是音乐或音效，不是说话）"):
        ok = out is not None and out.startswith(expect)
        shown = out or "None"
    else:
        ok = out == expect
        shown = out or "None"
    if not ok:
        fail += 1
    print(f"{'✅' if ok else '❌':8} {desc:16} {raw[:28]:30} -> {shown}")

print()
print(f"=== {len(CASES)-fail}/{len(CASES)} 通过 ===")

print()
print("=== 边界 ===")
for desc, raw in [("含<|但非标签", "a <| b"), ("空串", ""), ("纯空格", "   "), ("emoji 在中间", "说话🎼说话")]:
    print(f"  {desc}: {raw!r} -> {clean(raw)!r}")

