# RVC 推理驱动（流萤模型 liuying.pth）：把一段人声换成她的音色。
# 用法： python cover.py <输入音频> <输出wav> [pitch] [f0_method]
import hashlib
import os
import shutil
import sys
import tempfile
import traceback
from pathlib import Path

SING = Path(__file__).resolve().parent
os.chdir(SING)                 # rvc_cli 用 cwd 解析模型路径
sys.path.insert(0, str(SING / "rvc_cli"))

# rmvpe 期望在 <cwd>/rvc_cli/rvc/models/predictors/rmvpe.pt
rmvpe_target = SING / "rvc_cli" / "rvc" / "models" / "predictors" / "rmvpe.pt"
rmvpe_src = SING / "model" / "rmvpe.pt"
rmvpe_target.parent.mkdir(parents=True, exist_ok=True)
if not rmvpe_target.exists() and rmvpe_src.exists():
    shutil.copyfile(rmvpe_src, rmvpe_target)

from rvc_cli.rvc.infer.infer import VoiceConverter  # noqa: E402


def main():
    if len(sys.argv) < 3:
        raise SystemExit("用法：python cover.py <输入音频> <输出wav> [pitch] [f0_method]")
    src = Path(sys.argv[1]).resolve()
    dst = Path(sys.argv[2]).resolve()
    pitch = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    f0_method = sys.argv[4] if len(sys.argv) > 4 else "rmvpe"
    model = SING / "model" / "liuying.pth"
    if not model.is_file():
        raise FileNotFoundError(f"缺少 RVC 音色模型：{model}")

    # faiss 的 C++ 层读不了非 ASCII 路径。索引若在中文路径下，先复制到临时 ASCII 路径再用。
    def _ascii_index_path(index_path):
        if not index_path.exists():
            return ""
        absolute = str(index_path.resolve())
        if all(ord(ch) < 128 for ch in absolute):
            return absolute
        tag = hashlib.md5(absolute.encode("utf-8")).hexdigest()[:8]
        cache = Path(tempfile.gettempdir()) / "rvc-index"
        cache.mkdir(parents=True, exist_ok=True)
        dst_index = cache / f"voice-{tag}.index"
        if not dst_index.exists() or dst_index.stat().st_mtime < index_path.stat().st_mtime:
            shutil.copyfile(index_path, dst_index)
        return str(dst_index)

    index_path = _ascii_index_path(SING / "model" / "liuying.index")

    conv = VoiceConverter()
    print("[1/2] loading hubert ...", flush=True)
    conv.load_hubert("contentvec")
    print("[2/2] converting ...", flush=True)
    conv.convert_audio(
        audio_input_path=str(src),
        audio_output_path=str(dst),
        model_path=str(model),
        index_path=index_path,
        pitch=pitch,
        f0_method=f0_method,
        index_rate=0.75 if index_path else 0.0,
        volume_envelope=1,
        protect=0.5,
        hop_length=64,
        split_audio=False,
        f0_autotune=False,
        embedder_model="contentvec",
        clean_audio=False,
        export_format="WAV",
        sid=0,
    )
    print("OK ->", dst, dst.stat().st_size, "bytes", flush=True)


try:
    main()
except Exception:
    traceback.print_exc()
    sys.exit(1)
