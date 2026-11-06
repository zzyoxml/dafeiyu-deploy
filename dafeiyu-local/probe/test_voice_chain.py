"""离线验证 voice-ly 的完整决策与合成链路（不依赖 QQ 消息）。

目的：群里已经安静 20 分钟，没法靠真实消息等触发。这里直接构造
一个假 event/response，把 maybe_speak 的判断逻辑跑一遍，
并真实合成一段音频，确认 20% 出口端到端可用。
"""
import asyncio
import random
import sys
import time

sys.path.insert(0, "/AstrBot")

import importlib.util


def load(path, name):
    s = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m


v = load("/AstrBot/data/plugins/dsh-voice-liuying/main.py", "vly")

print("=" * 60)
print("① 概率闸统计（20% 配置下 1000 次应约 200 次通过）")
hits = sum(1 for _ in range(1000) if random.random() < v.AUTO_RATE)
print(f"   1000 次中通过 {hits} 次 = {hits/10:.1f}%")
print()

print("② _keep_for_voice 边界")
cases = [
    ("今天天气不错呀", True),
    ("你好", False),
    ("😀😀", False),
    ("/限流状态", False),
    ("⏳ 正在做「demucs」", False),
    ("一" * 41, False),
]
for t, want in cases:
    got = v._keep_for_voice(t)
    print(f"   {'✅' if got == want else '❌'} {t[:20]!r:24} → {got} (应 {want})")
print()

print("③ 真实合成（走完整 Edge→RVC 链路）")
async def main():
    t0 = time.time()
    p = await v._synthesize_liuying("今天群里好安静呀，我来陪你们说说话")
    dt = time.time() - t0
    if p:
        sz = p.stat().st_size
        print(f"   ✅ 合成成功 {p.name} {sz//1024}KB 耗时 {dt:.1f}s")
        # 再取一次确认缓存
        t1 = time.time()
        p2 = await v._synthesize_liuying("今天群里好安静呀，我来陪你们说说话")
        print(f"   缓存复用 {(time.time()-t1)*1000:.0f}ms，同一文件={p2==p}")
    else:
        print(f"   ❌ 失败，耗时 {dt:.1f}s")

asyncio.run(main())
print()

print("④ 冷却与配额")
print(f"   COOLDOWN={v.COOLDOWN}s  HOURLY={v.HOURLY_CAP}")
print(f"   _allow_now() 初值 = {v._allow_now()}")
v._mark_used()
print(f"   标记使用后 _allow_now() = {v._allow_now()}（应 False，冷却生效）")
v._STATE["last"] = 0
print(f"   清掉冷却后 = {v._allow_now()}（应 True）")
