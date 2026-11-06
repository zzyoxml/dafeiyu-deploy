"""让 qzone 的失败日志带上 repr 和 traceback。"""

import ast
import sys

P = "/AstrBot/data/plugins/dsh-qzone/main.py"
src = open(P, encoding="utf-8").read()

pairs = [
    (
        '''    except Exception as e:  # noqa: BLE001
        logger.warning("[qzone] 读群 %s 历史失败：%s", gid, e)
        return []''',
        '''    except Exception as e:  # noqa: BLE001
        logger.warning(
            "[qzone] 读群 %s 历史失败：%r type=%s", gid, e, type(e).__name__,
            exc_info=True,
        )
        return []''',
    ),
    (
        '''    except Exception as e:  # noqa: BLE001
        logger.warning("[qzone] 读主人私聊失败：%s", e)
        return []''',
        '''    except Exception as e:  # noqa: BLE001
        logger.warning(
            "[qzone] 读主人私聊失败：%r type=%s", e, type(e).__name__,
            exc_info=True,
        )
        return []''',
    ),
]

for old, new in pairs:
    if old not in src:
        print("[warn] 未匹配:", old.splitlines()[1].strip())
    else:
        src = src.replace(old, new, 1)
        print("[ok] 已替换")

try:
    ast.parse(src)
    print("[check] ast OK")
except SyntaxError as e:
    print("[check] SyntaxError:", e)
    sys.exit(1)

open(P, "w", encoding="utf-8").write(src)
print("[write] done")
