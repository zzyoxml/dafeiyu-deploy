#!/bin/bash
set -u
echo "=== 安装 funasr-onnx 到 sing/venv（复用已有 torch/numpy）==="
docker exec astrbot /AstrBot/data/sing/venv/bin/pip install \
  -i https://pypi.tuna.tsinghua.edu.cn/simple \
  funasr-onnx 2>&1 | tail -12

echo ""
echo "=== 验证 ==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "
import funasr_onnx
print('  funasr_onnx OK')
from funasr_onnx import SenseVoiceSmall
print('  SenseVoiceSmall 可导入')
import onnxruntime
print('  onnxruntime:', onnxruntime.__version__)
" 2>&1 | tail -8
