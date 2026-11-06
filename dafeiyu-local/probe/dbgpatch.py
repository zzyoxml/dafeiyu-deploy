# -*- coding: utf-8 -*-
import sys
P = '/AstrBot/data/plugins/dsh-steal/main.py'
src = open(P, encoding='utf-8').read()

OLD = '''            imgs = _extract_images(event)
            if not imgs:
                return
            _stat["seen"] += 1'''
NEW = '''            imgs = _extract_images(event)
            _segs = getattr(getattr(event, "message_obj", None), "message", None) or []
            _types = []
            for _s in _segs:
                try:
                    _types.append(str(getattr(_s, "type", _s))[:40])
                except BaseException:
                    _types.append("?")
            logger.info("[stealdbg] gid=%s nseg=%d types=%s imgs=%d flags=%s",
                        event.get_group_id(), len(_segs), _types, len(imgs),
                        [it.get("is_sticker") for it in imgs])
            if not imgs:
                return
            _stat["seen"] += 1'''
if OLD not in src:
    print('MISS'); sys.exit(1)
src = src.replace(OLD, NEW, 1)
open(P, 'w', encoding='utf-8').write(src)
print('debug patch ok')
