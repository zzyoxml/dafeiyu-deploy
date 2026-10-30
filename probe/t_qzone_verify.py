"""只验证：取 bot、读群历史、取 provider —— 不发布任何动态。"""

import asyncio
import importlib.util
import sys
import traceback

sys.path.insert(0, "/AstrBot")


async def main():
    spec = importlib.util.spec_from_file_location(
        "qzone_probe", "/AstrBot/data/plugins/dsh-qzone/main.py"
    )
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)

    # 从 AstrBot 运行时拿 Context
    ctx = None
    try:
        from astrbot.core.star.context import Context
        # 找一个已注册的 star 实例拿到 context
        from astrbot.core.star.star_manager import PluginManager
        for name, mod in list(sys.modules.items()):
            for attr in dir(mod):
                try:
                    obj = getattr(mod, attr)
                except Exception:
                    continue
                if hasattr(obj, "context") and obj.__class__.__name__ == "Main":
                    ctx = obj.context
                    print("  找到 Context 来自", name, attr)
                    break
            if ctx:
                break
    except Exception as e:
        print("  取 context 失败:", e)

    if ctx is None:
        print("  未拿到 Context，改用平台管理器直读")
        return

    # 构造插件实例测内部方法
    p = m.QzonePlugin.__new__(m.QzonePlugin)
    p.context = ctx
    p._bot_cache = None

    bot = await p._get_bot()
    print("  bot =", bot)

    pid = await p._chat_provider_id()
    print("  provider_id =", repr(pid))

    if bot:
        # 只读历史，不发布
        for gid in m.GROUP_WHITELIST:
            msgs = await m._fetch_group_msgs(bot, gid)
            print(f"  群 {gid}: 当天合格素材 {len(msgs)} 条")
            for x in msgs[:3]:
                print("    -", x[:60])


try:
    asyncio.run(main())
except Exception:
    traceback.print_exc()
