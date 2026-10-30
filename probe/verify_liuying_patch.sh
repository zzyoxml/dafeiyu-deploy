#!/bash
set -u
echo "=== 1. 确认补丁在部署文件里 ==="
docker exec astrbot sh -c "grep -n '_liuying_convert\|已转换为流萤音色' /AstrBot/data/plugins/dsh-voice/main.py" | sed 's/^/  /'

echo ""
echo "=== 2. 重载后日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "\[voice\] 已加载|\[voice-ly\] 已加载" | tail -3

echo ""
echo "=== 3. 确认 RVC 依赖可用（venv 里） ==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "
import torch, torchaudio
print('  torch:', torch.__version__)
print('  torchaudio:', torchaudio.__version__)
" 2>&1 | tail -3

echo ""
echo "=== 4. 语音缓存目录 ==="
ls -lht /opt/dafeiyu/data/astrbot/audio/voice-cache/ 2>/dev/null | head -3
