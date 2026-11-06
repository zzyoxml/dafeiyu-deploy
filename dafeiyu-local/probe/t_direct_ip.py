import asyncio, socket, edge_tts, os

REAL_IPS = ["150.171.28.10", "150.171.27.10"]
HOST = "speech.platform.bing.com"
_orig = socket.getaddrinfo


async def try_one(ip):
    def patched(host, port, *a, **kw):
        if host == HOST:
            return _orig(ip, port, *a, **kw)
        return _orig(host, port, *a, **kw)

    socket.getaddrinfo = patched
    try:
        c = edge_tts.Communicate("你好，我是小鲸鱼", "zh-CN-XiaoxiaoNeural", proxy=None)
        out = f"/tmp/t3_{ip}.mp3"
        await c.save(out)
        print(f"  {ip}: OK size={os.path.getsize(out)}")
    except Exception as e:
        print(f"  {ip}: FAIL {type(e).__name__} {str(e)[:120]}")
    finally:
        socket.getaddrinfo = _orig


async def go():
    for ip in REAL_IPS:
        await try_one(ip)


asyncio.run(go())
