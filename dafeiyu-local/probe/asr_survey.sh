#!/bin/bash
set -u
echo "=== 1. 容器状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}" 2>&1 | head -5

echo ""
echo "=== 2. 谁在说「听不清」==="
grep -rn "听不清" /opt/dafeiyu/data/astrbot/plugins/ 2>/dev/null \
  --include=*.py --include=*.yaml | grep -v ".bak" | head -10

echo ""
echo "=== 3. 上游原文里有没有 ==="
grep -rn "听不清" /opt/dafeiyu/repo/plugins/ 2>/dev/null --include=*.py | head -6

echo ""
echo "=== 4. 现有 STT 能力排查（AstrBot 容器内）==="
docker exec astrbot python3 -c "
mods = ['whisper','faster_whisper','funasr','vosk','speech_recognition',
        'openai','torch','torchaudio','ffmpeg', 'silk']
import importlib.util as u
for m in mods:
    ok = u.find_spec(m) is not None
    print(f'  {m:22} {\"✅\" if ok else \"❌\"}')
" 2>&1 | tail -12

echo ""
echo "=== 5. AstrBot 自带 STT 配置项 ==="
docker exec astrbot sh -c "ls /AstrBot/astrbot/core/stt/ 2>/dev/null || echo '  无 stt 目录'" 2>&1 | head -8
docker exec astrbot sh -c "grep -rn 'stt\|speech_to_text\|whisper' /AstrBot/astrbot/core/config/default.py 2>/dev/null | head -8" 2>&1 | head -10

echo ""
echo "=== 6. Record 组件当前怎么处理 ==="
docker exec astrbot sh -c "sed -n '1,40p' /AstrBot/astrbot/core/message/components.py | grep -n 'class Record' -A20 " 2>&1 | head -20
