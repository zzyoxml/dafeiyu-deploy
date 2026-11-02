#!/bin/bash
set -u
echo "=== 1. rich_transcription_postprocess 会输出什么标签 ==="
docker exec astrbot python3 -c "
from funasr_onnx.utils.postprocess_utils import rich_transcription_postprocess as r
samples = [
    '<|zh|><|NEUTRAL|><|Speech|><|woitn|>你好',
    '<|zh|><|HAPPY|><|Speech|><|woitn|>太好了',
    '<|zh|><|NEUTRAL|><|Singing|><|woitn|>歌词',
    '<|zh|><|NEUTRAL|><|BGM|><|woitn|>背景音乐',
    '<|en|><|NEUTRAL|><|Speech|><|woitn|>hello',
]
for s in samples:
    print(f'  {s[:40]:42} -> {r(s)}')
" 2>&1 | tail -8

echo ""
echo "=== 2. 情绪标签含义 ==="
docker exec astrbot python3 -c "
from funasr_onnx.utils.postprocess_utils import _EMOJI_MAP if False else None
" 2>/dev/null || \
docker exec astrbot sh -c "grep -n 'EMOJI\|emoji\|🎼\|😊' /AstrBot/data/sing/venv/lib/python3.12/site-packages/funasr_onnx/utils/postprocess_utils.py | head -12" 2>&1

echo ""
echo "=== 3. is_emotion 开关作用 ==="
docker exec astrbot sh -c "grep -n 'is_emotion' /AstrBot/astrbot/core/provider/sources/sensevoice_selfhosted_source.py" 2>&1
docker exec astrbot sh -c "sed -n '55,100p' /AstrBot/astrbot/core/provider/sources/sensevoice_selfhosted_source.py" 2>&1
