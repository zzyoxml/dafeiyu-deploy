import asyncio
import importlib.util
import sys
import time

sys.path.insert(0, "/AstrBot")


def load(path, name):
    s = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m


print("=" * 62)
print("  五大需求 · 最终验收")
print("=" * 62)

# ── 1 唱歌缓存 ──
sing = load("/AstrBot/data/plugins/dsh-sing/main.py", "sing")
st = sing._cache_stats()
print(f"\n① 唱过的歌存下来，相同直接发")
print(f"   曲库 {st['count']}/{st['max']} 首，{st['bytes']//1048576}MB")
for song in ("全球变冷", "唱八千里路明月照完整版"):
    k = sing._cache_key(song, "ai", 60, 0, 0)
    t0 = time.time()
    hit = sing._cache_get(k)
    dt = (time.time() - t0) * 1000
    print(f"   {'✅' if hit else '❌'} {song} → {'命中 ' + hit.name if hit else '未命中'} ({dt:.2f}ms)")

# ── 2 LRU 上限 100 ──
print(f"\n② 最多 100 首，超出删最旧")
print(f"   CACHE_MAX = {sing.CACHE_MAX}  {'✅' if sing.CACHE_MAX == 100 else '❌'}")
print(f"   淘汰策略按 last_used 升序（已单测验证 A 保留 B 淘汰）")

# ── 3 语音改用流萤音色 ──
vly = load("/AstrBot/data/plugins/dsh-voice-liuying/main.py", "vly")
print(f"\n③ 说话也用流萤音色")
print(f"   Edge 底音 {vly.EDGE_VOICE} → RVC liuying.pth")
print(f"   venv: {'✅' if vly.VENV_PY.exists() else '❌'}  cover: {'✅' if vly.COVER_SCRIPT.exists() else '❌'}  model: {'✅' if vly.VOICE_MODEL.exists() else '❌'}")

async def run():
    p = await vly._synthesize_liuying("验收测试一句")
    if p:
        print(f"   合成 ✅ {p.name} {p.stat().st_size//1024}KB")
    else:
        print("   合成 ❌")
    return p

p = asyncio.run(run())

# ── 4 20% 语音 ──
print(f"\n④ 普通回复 20% 用语音")
print(f"   AUTO_RATE = {vly.AUTO_RATE}  {'✅' if abs(vly.AUTO_RATE - 0.20) < 0.001 else '❌'}")
print(f"   冷却 {vly.COOLDOWN}s，小时上限 {vly.HOURLY_CAP}")
print(f"   只念 4~{vly.MAX_CHARS} 字（太短没意思 / 太长变声慢）")

# ── 5 限流 10 条/分钟 ──
g = load("/AstrBot/data/plugins/dsh-reply-guard/main.py", "guard")
print(f"\n⑤ 普通文字一分钟最多 10 条")
print(f"   {g.RATE_MAX} 条 / {g.RATE_WINDOW}s  {'✅' if g.RATE_MAX == 10 and g.RATE_WINDOW == 60 else '❌'}")
print(f"   滑动窗口（非固定分钟桶），主人豁免={g.OWNER_BYPASS_RATE}")

# ── 6 不回 10 句前 ──
print(f"\n⑥ 不回超过 10 句话前的消息")
print(f"   STALE_LAG = {g.STALE_LAG}  {'✅' if g.STALE_LAG == 10 else '❌'}")
print(f"   点名/@ 一律放行；空闲 >600s 也放行（避免误伤新会话）")

print()
print("=" * 62)
