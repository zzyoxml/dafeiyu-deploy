"""离线验证 dsh-stt-clean 的清洗逻辑。"""
import re

TAG_RE = re.compile(r"<\|[^|]+\|>")
SINGING_TAGS = ("Singing",)
MUSIC_TAGS = ("BGM", "Applause", "Laughter")


def clean(raw):
    """复刻插件逻辑。"""
    if "<|" not in raw:
        return None
    tags = set(TAG_RE.findall(raw))
    text = TAG_RE.sub("", raw).strip()
    if any(t in tags for t in SINGING_TAGS):
        prefix = "（对方在唱歌）"
    elif any(t in tags for t in MUSIC_TAGS):
        prefix = "（对方发的是音乐/音效，不是说话）"
    else:
        prefix = ""
    if not text:
        return prefix or "（对方发了一段没有识别出文字的音频）"
    if prefix:
        return f"{prefix}{text}"
    return text


CASES = [
    ("<|Singing|>不敢轻皮黄颜红萧萧不计俗世傲海笑只身甘迢今朝", "唱歌"),
    ("🎼노든 방 좋아 와的天지", "BGM"),
    ("<|Singing|>", "纯 Singing"),
    ("🎼", "纯 BGM"),
    ("糖葫芦或者桂花糖藕😊", "正常说话"),
    ("你好", "正常"),
    ("<|zh|><|NEUTRAL|><|Speech|><|woitn|>正常", "Speech 残留"),
]

print("=== 清洗逻辑验证 ===")
for raw, desc in CASES:
    out = clean(raw)
    if out is None:
        print(f"  不动  | {raw[:32]:34} | {desc}")
    else:
        has_tag = "<|" in out
        flag = "❌" if has_tag else "✅"
        print(f"  {flag} | {raw[:30]:32} | {desc}")
        print(f"       -> {out}")
    print()

print("=== 边界 ===")
for desc, raw in [("含<|但非标签", "a <| b"), ("空串", ""), ("只有空格", "   ")]:
    print(f"  {desc}: {raw!r} -> {clean(raw)!r}")
