#!/bin/bash
set -u
SING=/AstrBot/data/astrbot/sing
LOG=/root/sing-install2.log

echo "=== 用清华镜像 + 官方 CPU torch 源重装 ==="
echo "日志: $LOG"

# torch CPU 版必须从 pytorch 官方 CPU 索引安装，其余包走清华镜像
cat > /opt/dafeiyu/data/astrbot/sing/requirements-cpu.txt <<'EOF'
--extra-index-url https://download.pytorch.org/whl/cpu

torch==2.5.1+cpu
torchaudio==2.5.1+cpu
transformers==4.46.3
demucs==4.1.0
faiss-cpu==1.11.0
librosa==0.10.2.post1
safetensors==0.4.5
pedalboard==0.9.20
noisereduce==3.0.3
stftpitchshift==1.5.1
torchcrepe==0.0.23
local-attention==1.9.15
beautifulsoup4==4.12.3
pydub==0.25.1
numpy==1.26.4
soundfile
scipy
einops
EOF

echo ""
echo "=== 后台启动安装 ==="
nohup docker exec astrbot /AstrBot/data/sing/venv/bin/python -m pip install \
  --index-url https://pypi.tuna.tsinghua.edu.cn/simple \
  -r /AstrBot/data/sing/requirements-cpu.txt \
  > "$LOG" 2>&1 &

echo "  PID: $!"
sleep 30
echo ""
echo "=== 30 秒后进度 ==="
tail -12 "$LOG" 2>/dev/null
