#!/bin/bash
set -u
echo "=== 插件端到端测试（不发送，只产出文件）==="
echo "  测 20 秒 AI 翻唱，验证插件代码路径正确"
echo ""

cat > /tmp/test_e2e.py <<'PYEOF'
import asyncio, sys, time
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

async def main():
    song = "夜曲"
    seconds = 20
    t_all = time.time()

    print(f"[1] 搜索「{song}」")
    results = await mod._search_songs(song, 5)
    picked = mod._pick_candidate(results, song)
    print(f"    选中: {picked['title'][:50]}")
    print(f"    URL : {picked['url']}")
    print(f"    (排除伴奏前的原始 {len(results)} 条)")

    work = mod.WORK_DIR / f"e2e-{mod._stamp()}"
    work.mkdir(parents=True, exist_ok=True)
    print(f"[2] 工作目录: {work}")

    print(f"[3] 下载音频...")
    t = time.time()
    dl = await mod._download(picked["url"], work / "src")
    print(f"    完成 {dl.name} {dl.stat().st_size//1024}KB ({time.time()-t:.1f}s)")

    print(f"[4] 截取 {seconds}s...")
    clip = work / "clip.wav"
    await mod._cut(dl, clip, 30, seconds)
    print(f"    完成 {clip.stat().st_size//1024}KB")

    print(f"[5] demucs 分离人声...")
    t = time.time()
    vocals, inst = await mod._separate_vocals(clip, work)
    print(f"    完成 vocals={vocals.stat().st_size//1024}KB ({time.time()-t:.1f}s)")

    print(f"[6] RVC 流萤音色...")
    t = time.time()
    converted = work / "vocals-ai.wav"
    await mod._convert_voice(vocals, converted, 0)
    print(f"    完成 {converted.stat().st_size//1024}KB ({time.time()-t:.1f}s)")

    print(f"[7] 混音...")
    out = mod._unique_voice_path(f"e2e-test-{mod._stamp()}.mp3")
    await mod._mix(converted, inst, out, seconds)
    print(f"    完成 {out} {out.stat().st_size//1024}KB")

    print()
    print(f"✅ 全链路成功，总耗时 {time.time()-t_all:.1f}s")
    print(f"   成品: {out}")
    return str(out)

try:
    out = asyncio.run(main())
    print(f"\nRESULT_FILE={out}")
except Exception as e:
    import traceback
    print(f"\n❌ 失败: {type(e).__name__}: {e}")
    traceback.print_exc()
PYEOF
docker cp /tmp/test_e2e.py astrbot:/tmp/test_e2e.py
timeout 1800 docker exec astrbot python3 /tmp/test_e2e.py 2>&1 | grep -v "Retrying in\|MaxRetryError\|%|" | tail -30
