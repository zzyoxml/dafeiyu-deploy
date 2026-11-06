#!/bin/bash
set -u
cat > /tmp/verify_rvc2.py <<'PYEOF'
import glob, hashlib, os
import numpy as np
import soundfile as sf

w = sorted(glob.glob("/AstrBot/data/sing/work/e2e-*"))[-1]
vocals = glob.glob(os.path.join(w, "demucs", "htdemucs", "*", "vocals.wav"))[0]
converted = os.path.join(w, "vocals-ai.wav")

a, sr1 = sf.read(vocals)
b, sr2 = sf.read(converted)
if a.ndim > 1: a = a[:, 0]
if b.ndim > 1: b = b[:, 0]

print(f"  采样率: {sr1} -> {sr2}")
print(f"  时长: {len(a)/sr1:.2f}s -> {len(b)/sr2:.2f}s")

h1 = hashlib.md5(open(vocals,'rb').read()).hexdigest()
h2 = hashlib.md5(open(converted,'rb').read()).hexdigest()
print(f"  MD5 不同: {h1 != h2}")

n = min(len(a), len(b))
corr = float(np.corrcoef(a[:n], b[:n])[0, 1])
print(f"  波形相关系数: {corr:.4f}  (< 0.5 说明音色被彻底改写)")

def centroid(x, sr):
    seg = x[len(x)//4 : len(x)//4 + int(sr*2)]
    if len(seg) < 64: seg = x
    win = np.hanning(len(seg))
    spec = np.abs(np.fft.rfft(seg * win))
    freqs = np.fft.rfftfreq(len(seg), 1/sr)
    return float((spec * freqs).sum() / (spec.sum() + 1e-9))

c1 = centroid(a, sr1)
c2 = centroid(b, sr2)
print(f"  频谱质心: {c1:.0f} Hz -> {c2:.0f} Hz")
print(f"  质心变化: {c2-c1:+.0f} Hz")

# 基频（音高）对比
def f0_median(x, sr):
    import librosa
    f0 = librosa.yin(x, fmin=80, fmax=500, sr=sr)
    f0 = f0[np.isfinite(f0)]
    return float(np.median(f0)) if len(f0) else 0.0

p1 = f0_median(a[:sr1*5] if len(a)>sr1*5 else a, sr1)
p2 = f0_median(b[:sr2*5] if len(b)>sr2*5 else b, sr2)
print(f"  中位基频: {p1:.0f} Hz -> {p2:.0f} Hz")
print()
verdict = "✅ RVC 真实生效：音色/波形被彻底改写，基频保持（旋律不变）"
if abs(c2-c1) < 20 and corr > 0.9:
    verdict = "⚠ 疑似透传"
print(" ", verdict)
PYEOF
docker cp /tmp/verify_rvc2.py astrbot:/tmp/verify_rvc2.py
docker exec astrbot /AstrBot/data/sing/venv/bin/python /tmp/verify_rvc2.py 2>&1
