import pathlib
import re
import shutil
import time

P = pathlib.Path("/opt/dafeiyu/data/astrbot/plugins/dsh-voice/main.py")
bak = P.with_suffix(f".py.bak-edgefix-{time.strftime('%H%M%S')}")
shutil.copyfile(P, bak)
print(f"  已备份 → {bak.name}")

src = P.read_text(encoding="utf-8")

OLD = '''async def _edge_tts_once(text: str) -> tuple[bytes | None, str]:
    """调用 Edge ReadAloud WebSocket 作为独立网络/服务兜底。"""
    path = os.path.join(TMP_DIR, f"edge_{int(time.time() * 1000)}.mp3")
    try:
        await asyncio.wait_for(
            edge_tts.Communicate(text, EDGE_VOICE).save(path),
            timeout=min(TIMEOUT, 30),
        )
        with open(path, "rb") as f:
            audio = f.read()
        return (audio, "") if len(audio) > 256 else (None, "Edge 返回空音频")
    except asyncio.TimeoutError:
        return None, "Edge 超时（>30s）"
    except Exception as e:  # noqa: BLE001
        return None, f"Edge {type(e).__name__}: {e}"
    finally:
        try:
            os.remove(path)
        except OSError:
            pass'''

NEW = '''async def _edge_tts_once(text: str) -> tuple[bytes | None, str]:
    """调用 Edge ReadAloud WebSocket 作为独立网络/服务兜底。

    2026-10-30 修正：必须走 sing/venv 里的 edge-tts 7.3.1。
    镜像自带的主环境是 7.2.7，对 speech.platform.bing.com 恒定返回 403
    （Sec-MS-GEC 版本号过期，7.3.1 才带新的 Chromium 版本）。
    /AstrBot/data/sing/venv 在挂载卷上，--force-recreate 不会冲掉它。
    顺序：venv 子进程 → 本进程（旧版通常必然 403，留作兜底）。
    """
    path = os.path.join(TMP_DIR, f"edge_{int(time.time() * 1000)}.mp3")
    _VENV_PY = "/AstrBot/data/sing/venv/bin/python"

    if os.path.exists(_VENV_PY):
        script = os.path.join(TMP_DIR, f"_edge_{int(time.time() * 1000)}.py")
        try:
            with open(script, "w", encoding="utf-8") as f:
                f.write(
                    "import asyncio,sys\\n"
                    "import edge_tts\\n"
                    "async def m():\\n"
                    "    await edge_tts.Communicate(sys.argv[2], sys.argv[3])"
                    ".save(sys.argv[1])\\n"
                    "asyncio.run(m())\\n"
                )
            proc = await asyncio.create_subprocess_exec(
                _VENV_PY, script, path, text, EDGE_VOICE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            try:
                await asyncio.wait_for(proc.communicate(),
                                       timeout=min(TIMEOUT, 60))
            except asyncio.TimeoutError:
                proc.kill()
                return None, "Edge 超时（venv >60s）"
            if proc.returncode == 0 and os.path.exists(path):
                with open(path, "rb") as f:
                    audio = f.read()
                if len(audio) > 256:
                    return audio, ""
        except Exception as exc:  # noqa: BLE001
            logger.warning("[voice] venv Edge 失败，回退主环境：%s", exc)
        finally:
            try:
                os.remove(script)
            except OSError:
                pass

    try:
        await asyncio.wait_for(
            edge_tts.Communicate(text, EDGE_VOICE).save(path),
            timeout=min(TIMEOUT, 30),
        )
        with open(path, "rb") as f:
            audio = f.read()
        return (audio, "") if len(audio) > 256 else (None, "Edge 返回空音频")
    except asyncio.TimeoutError:
        return None, "Edge 超时（>30s）"
    except Exception as e:  # noqa: BLE001
        return None, f"Edge {type(e).__name__}: {e}"
    finally:
        try:
            os.remove(path)
        except OSError:
            pass'''

if OLD not in src:
    print("  ❌ 未找到原始代码（可能已改过），请人工检查")
    print("  当前 _edge_tts_once 前 60 行:")
    idx = src.find("async def _edge_tts_once")
    print(src[idx:idx + 1200] if idx > 0 else "  未找到函数")
    raise SystemExit(1)

src = src.replace(OLD, NEW, 1)
P.write_text(src, encoding="utf-8")
print(f"  ✅ 已替换，文件 {len(src)} 字符")

# 语法校验
import ast
ast.parse(P.read_text(encoding="utf-8"))
print("  ✅ 语法 OK")
