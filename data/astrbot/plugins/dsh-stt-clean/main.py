"""dsh-stt-clean v1.0.1  STT 结果清洗

SenseVoice 的 rich_transcription_postprocess 有个已知缺陷：
- 情绪标签 (HAPPY/SAD/...) 会变成 emoji（😊），这个可以留
- event 标签里只有 BGM 被转成 🎼，**Singing 原样留下 <|Singing|>**
- 于是群里有人唱歌时，LLM 收到的是 <|Singing|>不敢轻皮黄颜红...

本插件在 message_str 进入 LLM 之前做一次清洗：
1. 剥掉所有残留的 <|XXX|> 标签
2. 识别出这段是唱歌/音乐，加一个朴素的前缀让人格知道
3. 纯音乐（无有效文字）直接标记，避免模型硬答歌词

只做文本规整，绝不拦消息。

v1.0.1 修 two bugs:
  - 原先用 `if "Singing" in tags`，但 tags 存的是完整标签 `<|Singing|>`，
    集合判断是精确匹配，永远 False，前缀从没加上过。改为剥壳后匹配。
  - BGM 已被后处理转成 🎼 emoji，正则找不到 `<|BGM|>`。补 emoji 检测。
"""

import re

from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.star import Context, Star, register

# 匹配 <|Singing|> 这种标签
TAG_FULL_RE = re.compile(r"<\|([^|]+)\|>")
TAG_RE = re.compile(r"<\|[^|]+\|>")

# 唱歌 / 音乐 标记
SINGING_NAMES = {"Singing"}
MUSIC_NAMES = {"BGM", "Applause", "Laughter"}
MUSIC_EMOJI = "🎼"


@register(
    "dsh-stt-clean",
    "大肥鱼",
    "STT 结果清洗：剥掉 SenseVoice 残留的 <|Singing|> 等标签，给唱歌/音乐加朴素前缀。",
    "1.0.1",
)
class SttCleanPlugin(Star):
    def __init__(self, context: Context, config: dict | None = None):
        super().__init__(context)
        self.cfg = config or {}

    @filter.on_llm_request()
    async def clean_stt(self, event: AstrMessageEvent, req):
        raw = event.message_str or ""
        # 快速跳过：既没有残留标签，也没有音乐 emoji
        if "<|" not in raw and MUSIC_EMOJI not in raw:
            return

        # 剥壳取标签裸名（关键修复：原先直接拿完整标签做精确匹配，永远 False）
        names = set(TAG_FULL_RE.findall(raw))
        text = TAG_RE.sub("", raw).strip()

        if names & SINGING_NAMES:
            prefix = "（对方在唱歌）"
        elif (names & MUSIC_NAMES) or MUSIC_EMOJI in text:
            prefix = "（对方发的是音乐或音效，不是说话）"
        else:
            prefix = ""

        if not text:
            new = prefix or "（对方发了一段没有识别出文字的音频）"
        elif prefix:
            new = f"{prefix}{text}"
        else:
            new = text

        event.message_str = new
        try:
            event.message_obj.message_str = new
        except Exception:
            pass
        try:
            from astrbot.core.message.components import Plain
            for comp in event.message_obj.message:
                if isinstance(comp, Plain) and "<|" in (comp.text or ""):
                    comp.text = TAG_RE.sub("", comp.text).strip()
        except Exception:
            pass

        try:
            from astrbot.api import logger
            logger.info(f"[stt-clean] {raw[:40]!r} -> {new[:40]!r}")
        except Exception:
            pass
