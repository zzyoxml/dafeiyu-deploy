#!/bin/bash
set -u
echo "=== 1. 首次加载 SenseVoice（会下载模型，需几分钟）==="
timeout 900 docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "
import time, os
t0=time.time()
from funasr_onnx import SenseVoiceSmall
m = SenseVoiceSmall('/AstrBot/data/stt-models/SenseVoiceSmall', quantize=True, batch_size=1)
print(f'  模型加载 {time.time()-t0:.1f}s')
print('  model_dir:', os.path.dirname(m.model_path) if hasattr(m,'model_path') else '?')
" 2>&1 | tail -15

echo ""
echo "=== 2. 模型文件在哪 ==="
docker exec astrbot sh -c "du -sh /AstrBot/data/stt-models/* 2>/dev/null; ls /AstrBot/data/stt-models/*/ 2>/dev/null | head -10" 2>&1
