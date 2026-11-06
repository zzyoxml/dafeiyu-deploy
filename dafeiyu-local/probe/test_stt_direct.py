"""直接实例化 SenseVoice provider，绕过 ProviderManager 的循环导入。"""
import asyncio
import glob
import os
import sys
import time

MP = "/AstrBot/data/stt-models/models/iic--SenseVoiceSmall-onnx/snapshots/master"


async def main():
    # 只导入 source 模块，不碰 manager
    from astrbot.core.provider.sources.sensevoice_selfhosted_source import (
        ProviderSenseVoiceSTTSelfHost,
    )

    print("=== 1. 实例化 provider ===")
    cfg = {"stt_model": MP, "is_emotion": False}
    p = ProviderSenseVoiceSTTSelfHost(cfg, {})
    t0 = time.time()
    await p.initialize()
    print(f"  初始化 {time.time()-t0:.1f}s")
    print(f"  model_name: {p.model_name}")

    print()
    print("=== 2. get_text 端到端（这次走 MediaResolver，模拟真实链路）===")
    tests = [
        ("/tmp/stt-test2/0.wav", "糖葫芦或者桂花糖藕"),
        ("/tmp/stt-test2/1.wav", "今天下午两点多这时候就想来点甜的"),
        ("/tmp/stt-test2/2.wav", "小鲸鱼你听得见我说话吗"),
    ]
    for path, expect in tests:
        if not os.path.exists(path):
            print(f"  ⚠ 缺文件 {path}")
            continue
        t0 = time.time()
        try:
            got = await p.get_text(audio_url=path)
            dt = time.time() - t0
            ok = got and got.strip()
            print(f"  期望: {expect}")
            print(f"  实际: {got}")
            print(f"  {'✅' if ok else '❌ 空'}  {dt:.2f}s")
        except Exception as e:
            import traceback
            traceback.print_exc()
        print()

    print("=== 3. 真实 QQ 语音文件 ===")
    files = sorted(glob.glob("/AstrBot/data/temp/media_audio_*.wav"),
                   key=lambda f: -os.path.getsize(f))[:3]
    for f in files:
        t0 = time.time()
        try:
            got = await p.get_text(audio_url=f)
            print(f"  {os.path.basename(f)[-18:]} ({os.path.getsize(f)//1024}KB) -> {got}  ({time.time()-t0:.2f}s)")
        except Exception as e:
            print(f"  ❌ {type(e).__name__}: {str(e)[:80]}")
        print()

asyncio.run(main())
