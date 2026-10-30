import asyncio, json, sys
sys.path.insert(0, "/AstrBot")

async def go():
    # 从 AstrBot 运行时拿现有 aiocqhttp 适配器
    import astrbot.core.core_lifecycle as cl
    core = None
    for attr in ("astrbot_core_lifecycle", "core_lifecycle", "_instance"):
        core = getattr(cl, attr, None)
        if core is not None:
            break
    print("core:", type(core).__name__ if core else None)

    # 更直接：扫 astrbot 的 platform manager
    try:
        from astrbot.core import AstrBotConfig
        from astrbot.core.platform.manager import PlatformManager
        print("PlatformManager imported")
    except Exception as e:
        print("import fail:", e)

asyncio.run(go())
