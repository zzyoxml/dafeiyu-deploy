"""修复 dsh-qzone：llm_generate 的 chat_provider_id 必填 + bot 获取更稳 + 日志更细。"""

import ast
import sys

P = "/AstrBot/data/plugins/dsh-qzone/main.py"
src = open(P, encoding="utf-8").read()

# ── 修复 1：llm_generate 需要真实 provider id ────────────────────────
old = '''        try:
            resp = await self.context.llm_generate(
                chat_provider_id=None,
                prompt=prompt,
                max_tokens=CHAT_MODEL_TOKENS,
            )
            text = (getattr(resp, "completion_text", None) or str(resp)).strip()
        except Exception as e:  # noqa: BLE001
            logger.warning("[qzone] 文案生成失败：%s", e)
            return "生成失败"'''

new = '''        try:
            provider_id = await self._chat_provider_id()
            if not provider_id:
                logger.warning("[qzone] 找不到可用的对话模型 Provider")
                return "无对话模型"
            resp = await self.context.llm_generate(
                chat_provider_id=provider_id,
                prompt=prompt,
            )
            text = (getattr(resp, "completion_text", None) or "").strip()
            if not text:
                text = str(resp).strip()
        except Exception as e:  # noqa: BLE001
            logger.warning("[qzone] 文案生成失败：%s", e)
            return "生成失败"'''

if old not in src:
    print("[fix1] FAIL: 未匹配 llm_generate 块")
    sys.exit(1)
src = src.replace(old, new, 1)
print("[fix1] llm_generate provider_id OK")

# ── 修复 2：新增 _chat_provider_id 方法 ──────────────────────────────
anchor = '''    async def _get_bot(self):'''
addition = '''    async def _chat_provider_id(self) -> str:
        """优先用当前会话模型，回落到第一个可用 provider。"""
        try:
            pid = await self.context.get_current_chat_provider_id(umo=None)
            if pid:
                return pid
        except Exception as e:  # noqa: BLE001
            logger.debug("[qzone] 取当前 provider 失败：%s", e)
        try:
            provs = self.context.get_all_providers() or []
            if provs:
                return getattr(provs[0], "provider_config", {}).get(
                    "id"
                ) or getattr(provs[0], "id", "") or ""
        except Exception as e:  # noqa: BLE001
            logger.debug("[qzone] 枚举 provider 失败：%s", e)
        return ""

    async def _get_bot(self):'''

if anchor not in src:
    print("[fix2] FAIL: 未找到 _get_bot 锚点")
    sys.exit(1)
src = src.replace(anchor, addition, 1)
print("[fix2] _chat_provider_id 已插入")

# ── 修复 3：_get_bot 优先用 get_platform_inst ────────────────────────
old_bot = '''    async def _get_bot(self):
        """取 aiocqhttp 平台的 bot 实例。"""
        try:
            for p in self.context.platform_manager.platform_insts:
                b = getattr(p, "bot", None)
                if b is not None and hasattr(b, "call_action"):
                    return b
        except Exception as e:  # noqa: BLE001
            logger.warning("[qzone] 取 bot 失败：%s", e)
        return None'''

new_bot = '''    async def _get_bot(self):
        """取 aiocqhttp 平台的 bot 实例（带缓存）。"""
        if getattr(self, "_bot_cache", None) is not None:
            return self._bot_cache
        try:
            insts = getattr(
                getattr(self.context, "platform_manager", None), "platform_insts", []
            ) or []
            for p in insts:
                b = getattr(p, "bot", None)
                if b is not None and hasattr(b, "call_action"):
                    self._bot_cache = b
                    logger.info(
                        "[qzone] 已绑定 OneBot 平台：%s", type(p).__name__
                    )
                    return b
            logger.warning(
                "[qzone] 未找到带 call_action 的平台，现有 %d 个：%s",
                len(insts),
                [type(p).__name__ for p in insts],
            )
        except Exception as e:  # noqa: BLE001
            logger.warning("[qzone] 取 bot 失败：%s", e)
        return None'''

if old_bot not in src:
    print("[fix3] FAIL: 未匹配 _get_bot")
    sys.exit(1)
src = src.replace(old_bot, new_bot, 1)
print("[fix3] _get_bot 加固 OK")

# ── 修复 4：py3.12 下 datetime.fromtimestamp 用本地时区即可，但补时区安全 ──
src = src.replace(
    "from datetime import datetime, timedelta",
    "from datetime import datetime, timedelta\nfrom zoneinfo import ZoneInfo\n\nTZ = ZoneInfo(\"Asia/Shanghai\")",
    1,
)
src = src.replace("datetime.now()", "datetime.now(TZ)")
src = src.replace("datetime.fromtimestamp(ts).date()", "datetime.fromtimestamp(ts, TZ).date()")
src = src.replace("datetime.fromtimestamp(last_at)", "datetime.fromtimestamp(last_at, TZ)")
src = src.replace("datetime.fromtimestamp(p.get(\"at\", 0))", "datetime.fromtimestamp(p.get(\"at\", 0), TZ)")
print("[fix4] 时区改为 Asia/Shanghai")

try:
    ast.parse(src)
    print("[check] ast OK")
except SyntaxError as e:
    print("[check] SyntaxError:", e)
    sys.exit(1)

open(P, "w", encoding="utf-8").write(src)
print("[write] 已写回")
