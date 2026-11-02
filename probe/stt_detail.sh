#!/bin/bash
set -u
echo "=== 1. _stt_record 完整实现 ==="
docker exec astrbot sh -c "sed -n '215,300p' /AstrBot/astrbot/core/pipeline/preprocess_stage/stage.py" 2>&1

echo ""
echo "=== 2. 支持哪些 STT provider 类型 ==="
docker exec astrbot sh -c "grep -rn 'speech_to_text\|stt' /AstrBot/astrbot/core/provider/sources/*.py 2>/dev/null | head -12" 2>&1

echo ""
echo "=== 3. provider sources 目录 ==="
docker exec astrbot sh -c "ls /AstrBot/astrbot/core/provider/sources/ 2>/dev/null | grep -iE 'stt|whisper|speech|mimo'" 2>&1
