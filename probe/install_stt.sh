#!/bin/bash
# 安装 SenseVoice STT（本地 ONNX 推理，无需 API key）
#
# 踩过的坑（按顺序）：
#  1. iic/SenseVoiceSmall 是 PyTorch 版（892MB model.pt），funasr_onnx 只吃
#     model_quant.onnx，所以必须下 iic/SenseVoiceSmall-onnx
#  2. ONNX 那个仓库缺 chn_jpn_yue_eng_ko_spectok.bpe.model（377KB），
#     要单独从 iic/SenseVoiceSmall 补，否则加载报 RuntimeError NOT_FOUND
#  3. funasr_onnx 必须装进 **AstrBot 主环境**——provider 在容器主进程加载，
#     只装 sing/venv 会报 ModuleNotFoundError: No module named 'funasr_onnx'
#  4. is_emotion 必须 false，否则会把「(当前的情绪：HAPPY)」写进文本
#
# 模型最终 231MB，装在 /AstrBot/data/stt-models（挂载卷，容器重建不丢）
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
