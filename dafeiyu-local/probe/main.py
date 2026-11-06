from astrbot.api import logger
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.star import Context, Star
from astrbot.core.platform.message_type import MessageType
import json

class ImgProbe(Star):
    def __init__(self, context: Context):
        super().__init__(context)
        logger.info("[imgprobe] loaded")

    @filter.event_message_type(filter.EventMessageType.ALL, priority=-998)
    async def probe(self, event: AstrMessageEvent):
        try:
            if event.get_message_type() != MessageType.GROUP_MESSAGE:
                return
            segs = getattr(getattr(event, "message_obj", None), "message", None) or []
            has_img = False
            for seg in segs:
                ty = str(getattr(seg, "type", "")).lower()
                if "image" not in ty:
                    continue
                has_img = True
                try:
                    d = seg.toDict()
                except BaseException:
                    d = {}
                logger.info("[imgprobe] SEG=%s", json.dumps(d, ensure_ascii=False)[:900])
            if has_img:
                raw = getattr(getattr(event, "message_obj", None), "raw_message", None)
                try:
                    logger.info("[imgprobe] RAW=%s", json.dumps(raw, ensure_ascii=False, default=str)[:1200])
                except BaseException as e:
                    logger.info("[imgprobe] RAWERR=%r", e)
        except BaseException as e:
            logger.warning("[imgprobe] err %r", e)

    async def terminate(self):
        pass
