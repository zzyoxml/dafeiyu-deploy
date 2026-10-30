#!/bin/bash
set -u
echo "=== 验证语音变声真实性 ==="
cat > /tmp/verify_voice_rvc.py <<'PYEOF'
import numpy as np, soundfile as sf, hashlib

a, sr1 = sf.read("/tmp/tts-raw.wav")     # Edge 原始
b, sr2 = sf.read("/tmp/tts-liuying.wav") # RVC 后
if a.ndim > 1: a = a[:,0]
if b.ndim > 1: b = b[:,0]

print(f"  采样率: {sr1} -> {sr2}")
print(f"  长度: {len(a)} -> {len(b)}")

h1 = hashlib.md5(open("/tmp/tts-raw.wav","rb").read()).hexdigest()
h2 = hashlib.md5(open("/tmp/tts-liuying.wav","rb").read()).hexdigest()
print(f"  MD5 不同: {h1 != h2}")

n = min(len(a), len(b))
corr = float(np.corrcoef(a[:n], b[:n])[0,1])
print(f"  波形相关系数: {corr:.4f}")

def centroid(x, sr):
    seg = x[len(x)//4:len(x)//4+int(sr*2)]
    if len(seg) < 64: seg = x
    spec = np.abs(np.fft.rfft(seg*np.hanning(len(seg))))
    fr = np.fft.rfftfreq(len(seg), 1/sr)
    return float((spec*fr).sum()/(spec.sum()+1e-9))

c1, c2 = centroid(a,sr1), centroid(b,sr2)
print(f"  频谱质心: {c1:.0f} -> {c2:.0f} Hz ({c2-c1:+.0f})")

import librosa
def f0(x, sr):
    v = librosa.yin(x[:sr*3] if len(x)>sr*3 else x, fmin=60, fmax=500, sr=sr)
    v = v[np.isfinite(v)]
    return float(np.median(v)) if len(v) else 0
p1, p2 = f0(a,sr1), f0(b,sr2)
print(f"  中位基频: {p1:.0f} -> {p2:.0f} Hz")

print()
ok = (h1 != h2) and corr < 0.9
print(f"  {'✅ 流萤音色转换真实生效' if ok else '⚠ 疑似透传'}")
PYEOF
docker cp /tmp/verify_voice_rvc.py astrbot:/tmp/verify_voice_rvc.py
docker exec astrbot /AstrBot/data/sing/venv/bin/python /tmp/verify_voice_rvc.py 2>&1 | tail -14

echo ""
echo "=== 复制试听到 Windows ==="
cp /opt/dafeiyu/data/astrbot/audio/voice-liuying-test.mp3 <LOCAL_ROOT>/流萤音色-说话试听.mp3 2>/dev/null && \
  echo "  ✅ <LOCAL_ROOT>/流萤音色-说话试听.mp3"
