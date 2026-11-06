#!/bin/bash
set -u
echo "=== 1. 热重载两个语音插件 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
for p in dsh-voice dsh-voice-liuying; do
  R=$(curl -s -m 30 -X POST "http://127.0.0.1:6185/api/plugin/reload" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $JWT" \
    -d "{\"name\":\"$p\"}" 2>&1 | head -c 90)
  echo "  $p → $R"
done
sleep 3

echo ""
echo "=== 2. 加载确认 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -E "Plugin dsh-voice.*by 大肥鱼|\[voice\] 已加载|\[voice-ly\] 已加载" | tail -4

echo ""
echo "=== 3. 最终功能清单 ==="
echo ""
echo "  【唱歌】dsh-sing"
docker exec astrbot sh -c "grep -c 'filter.regex' /AstrBot/data/astrbot/plugins/dsh-sing/main.py 2>/dev/null || grep -c 'filter.regex' /AstrBot/data/plugins/dsh-sing/main.py"
echo "    命令数（含正则装饰器）↑"
CACHE=$(docker exec astrbot python3 -c "
import sys; sys.path.insert(0,'/AstrBot')
import importlib.util
s=importlib.util.spec_from_file_location('s','/AstrBot/data/plugins/dsh-sing/main.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
st=m._cache_stats(); print(f\"{st['count']}/{st['max']}\")" 2>/dev/null | tail -1)
echo "    曲库缓存: $CACHE"

echo ""
echo "  【语音】"
echo "    概率 20%｜流萤音色（Edge+RVC）｜/流萤说 /流萤语音状态"

echo ""
echo "  【节流】"
echo "    10条/60s｜滞后>10句不接话｜/限流状态"

echo ""
echo "=== 4. 环境变量确认 ==="
docker exec astrbot sh -c "env | grep -E '^DSH_(SING_CACHE|VOICE_LY_RATE|GUARD_RATE_MAX)' | sort" | sed 's/^/    /'

echo ""
echo "=== 5. 目录状态 ==="
echo "  曲库: $(ls /opt/dafeiyu/data/astrbot/sing/song-cache/*.mp3 2>/dev/null | wc -l) 首"
echo "  语音缓存: $(ls /opt/dafeiyu/data/astrbot/audio/voice-cache/*.mp3 2>/dev/null | wc -l) 句"
echo "  work 残留: $(find /opt/dafeiyu/data/astrbot/sing/work -maxdepth 1 -type d ! -path '*/work' 2>/dev/null | wc -l) 个"
