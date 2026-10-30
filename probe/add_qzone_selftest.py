"""在 dsh-qzone 的 initialize 里插入一次性自检：只读素材、不发布。"""

import ast
import sys

P = "/AstrBot/data/plugins/dsh-qzone/main.py"
src = open(P, encoding="utf-8").read()

old = '''    async def initialize(self):
        if not ENABLED:
            logger.info("[qzone] 未启用（DSH_QZONE_ENABLED=0）")
            return
        self._task = asyncio.create_task(self._loop())
        logger.info("[qzone] 定时器已启动")'''

new = '''    async def initialize(self):
        if not ENABLED:
            logger.info("[qzone] 未启用（DSH_QZONE_ENABLED=0）")
            return

        if os.environ.get("DSH_QZONE_SELFTEST") == "1":
            self._task = asyncio.create_task(self._selftest())

        self._task = asyncio.create_task(self._loop())
        logger.info("[qzone] 定时器已启动")

    async def _selftest(self):
        """一次性自检：取 bot / provider / 读群历史，不发布。"""
        await asyncio.sleep(25)
        try:
            logger.info("[qzone][自检] 开始")
            bot = await self._get_bot()
            logger.info("[qzone][自检] bot = %s", bot)
            pid = await self._chat_provider_id()
            logger.info("[qzone][自检] provider_id = %r", pid)
            if bot is None:
                logger.warning("[qzone][自检] 无 bot，终止")
                return
            total = 0
            for gid in GROUP_WHITELIST:
                msgs = await _fetch_group_msgs(bot, gid)
                total += len(msgs)
                logger.info("[qzone][自检] 群 %s 当天合格素材 %d 条", gid, len(msgs))
                for x in msgs[:3]:
                    logger.info("[qzone][自检]   样例: %s", x[:60])
            pm = await _fetch_private_msgs(bot, OWNER_ID)
            total += len(pm)
            logger.info("[qzone][自检] 主人私聊 %d 条", len(pm))
            logger.info("[qzone][自检] 素材合计 %d 条", total)
        except Exception as e:  # noqa: BLE001
            logger.error("[qzone][自检] 异常：%s", e, exc_info=True)'''

if old not in src:
    print("[selftest] FAIL 未匹配 initialize")
    sys.exit(1)
src = src.replace(old, new, 1)

try:
    ast.parse(src)
    print("[check] ast OK")
except SyntaxError as e:
    print("[check] SyntaxError:", e)
    sys.exit(1)

open(P, "w", encoding="utf-8").write(src)
print("[write] 自检代码已插入")
