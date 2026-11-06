"""直接调用 AstrBot 的 STT provider，验证端到端链路。"""
import asyncio
import sys
import time

sys.path.insert(0, "/AstrBot")

async def main():
    from astrbot.core.provider.manager import ProviderManager
    from astrbot.core.config.astrbot_config import AstrBotConfig

    cfg = AstrBotConfig()
    pm = ProviderManager(cfg, None)

    print("=== 1. 找 STT provider ===")
    stt = await pm.get_provider_by_id("sensevoice/SenseVoiceSmall")
    if not stt:
        print("  ❌ 找不到 provider")
        # 列出所有
        for pid, p in list(pm.provider_insts.items()):
            print(f"  have: {pid}")
        return
    print(f"  ✅ {type(stt).__name__}")

    print()
    print("=== 2. 调用 get_text（模拟真实语音）===")
    tests = [
        ("/tmp/stt-test2/0.wav", "糖葫芦或者桂花糖藕"),
        ("/tmp/stt-test2/1.wav", "今天下午两点多，这时候就想来点甜的"),
        ("/tmp/stt-test2/2.wav", "小鲸鱼你听得见我说话吗"),
    ]
    for path, expect in tests:
        t0 = time.time()
        try:
            got = await stt.get_text(audio_url=path)
            dt = time.time() - t0
            print(f"  期望: {expect}")
            print(f"  实际: {got}")
            print(f"  {'✅' if got and got.strip() else '❌ 空'}  ({dt:.2f}s)")
        except Exception as e:
            print(f"  ❌ {type(e).__name__}: {e}")
        print()

    print("=== 3. 用 QQ silk/amr 真实文件 ===")
    import glob
    amrs = glob.glob("/AstrBot/data/temp/media_audio_*.wav")
    amrs = sorted(amrs, key=lambda f: -__import__("os").path.getsize(f))[:2]
    for f in amrs:
        t0 = time.time()
        try:
            got = await stt.get_text(audio_url=f)
            print(f"  {__import__('os').path.basename(f)} -> {got}  ({time.time()-t0:.2f}s)")
        except Exception as e:
            print(f"  ❌ {type(e).__name__}: {str(e)[:100]}")
        print()

asyncio.run(main())
