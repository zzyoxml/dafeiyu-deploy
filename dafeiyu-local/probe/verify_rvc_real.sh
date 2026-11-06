#!/bin/bash
set -u
echo "=== 验证 RVC 是否真的改变了音色（而非透传）==="
cat > /tmp/verify_rvc.py <<'PYEOF'
import hashlib, os, subprocess, sys
import numpy as np
import soundfile as sf

# 找 E2E 留下的工作目录
import glob
dirs = sorted(glob.glob("/AstrBot/data/sing/work/e2e-*"))
if not dirs:
    print("  没有 e2e 工作目录（已被清理）")
    sys.exit(0)
w = dirs[-1]
print("  工作目录:", w)

vocals = os.path.join(w, "demucs", "htdemucs", "clip", "vocals.wav")
if not os.path.exists(vocals):
    # 文件名可能是 clip.wav 的 stem
    import glob as g
    cands = g.glob(os.path.join(w, "demucs", "htdemucs", "*", "vocals.wav"))
    if not cands:
        print("  找不到 vocals.wav")
        sys.exit(0)
    vocals = cands[0]
converted = os.path.join(w, "vocals-ai.wav")
print("  原始人声:", vocals, os.path.getsize(vocals) if os.path.exists(vocals) else "缺失")
print("  RVC 输出:", converted, os.path.getsize(converted) if os.path.exists(converted) else "缺失")

if not (os.path.exists(vocals) and os.path.exists(converted)):
    sys.exit(0)

a, sr1 = sf.read(vocals)
b, sr2 = sf.read(converted)
print(f"  采样率: {sr1} -> {sr2}")
print(f"  长度: {len(a)} -> {len(b)}")

# 取等长部分比较
n = min(len(a), len(b))
a, b = a[:n], b[:n]
if a.ndim > 1: a = a[:, 0]
if b.ndim > 1: b = b[:, 0]

# 1. 文件哈希
h1 = hashlib.md5(open(vocals,'rb').read()).hexdigest()
h2 = hashlib.md5(open(converted,'rb').read()).hexdigest()
print(f"  MD5 相同: {h1 == h2}  (False = 已被改写)")

# 2. 相关性（接近 1 说明只是复制；明显 < 1 说明真的换了特征）
corr = float(np.corrcoef(a, b)[0, 1])
print(f"  波形相关系数: {corr:.4f}")

# 3. 频谱质心（音色高低的客观指标）
def centroid(x, sr, nfft=2048):
    # 取中间一段
    seg = x[len(x)//4 : len(x)//4 + 44100*2] if len(x) > 44100*2 else x
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), nfft*8))
    freqs = np.fft.rfftfreq(len(seg)*8, 1/sr)
    return float((spec * freqs).sum() / (spec.sum() + 1e-9))

c1 = centroid(a, sr1)
c2 = centroid(b, sr2)
print(f"  频谱质心: {c1:.1f} Hz -> {c2:.1f} Hz  (差异 {abs(c2-c1):.1f} Hz)")

changed = (h1 != h2) and (corr < 0.98)
print()
print(f"  {'✅ 音色确实被转换了' if changed else '⚠ 疑似透传，未真正转换'}")
PYEOF
docker cp /tmp/verify_rvc.py astrbot:/tmp/verify_rvc.py
docker exec astrbot /AstrBot/data/sing/venv/bin/python /tmp/verify_rvc.py 2>&1
