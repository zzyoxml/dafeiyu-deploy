#!/bin/bash
set -u
echo "=== 安装日志尾部 ==="
tail -4 /root/sing-install2.log 2>/dev/null
echo ""
echo "=== pip 是否还在跑 ==="
if pgrep -f "pip install" > /dev/null; then echo "  仍在安装"; else echo "  已结束"; fi
echo ""
echo "=== 验证 torch / demucs ==="
cat > /tmp/verify_sing.py <<'PYEOF'
import sys
ok = True
try:
    import torch
    print("  torch:", torch.__version__, "| cuda:", torch.cuda.is_available())
except Exception as e:
    print("  torch 失败:", e); ok = False
try:
    import demucs
    print("  demucs: OK")
except Exception as e:
    print("  demucs 失败:", e); ok = False
try:
    import torchaudio
    print("  torchaudio:", torchaudio.__version__)
except Exception as e:
    print("  torchaudio 失败:", e); ok = False
try:
    import librosa, faiss, soundfile
    print("  librosa/faiss/soundfile: OK")
except Exception as e:
    print("  音频库失败:", e); ok = False
sys.exit(0 if ok else 1)
PYEOF
docker cp /tmp/verify_sing.py astrbot:/tmp/verify_sing.py
docker exec astrbot /AstrBot/data/sing/venv/bin/python /tmp/verify_sing.py 2>&1
