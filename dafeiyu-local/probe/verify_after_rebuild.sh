#!/bin/bash
set -u
echo "=== 1. 容器内 env 实际值（重建后是否生效）==="
docker exec astrbot sh -c "env | grep -E '^DSH_(SING|VOICE_LY|GUARD)' | sort" | sed 's/^/  /'

echo ""
echo "=== 2. 插件加载情况 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "\[guard\] 已加载|\[voice-ly\] 已加载|Plugin dsh-sing|Plugin dsh-reply-guard|Plugin dsh-voice-liuying" | tail -8

echo ""
echo "=== 3. 加载失败检查 ==="
FAIL=$(docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -icE "加载失败|Failed to load plugin" || true)
echo "  失败次数: $FAIL"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "加载失败|Failed to load plugin" | tail -3

echo ""
echo "=== 4. WebUI 可达 ==="
curl -s -m 5 -o /dev/null -w "  HTTP %{http_code}\n" http://127.0.0.1:6185/

echo ""
echo "=== 5. 唱歌缓存目录状态 ==="
ls -la /opt/dafeiyu/data/astrbot/sing/song-cache/ 2>/dev/null | head -3 || echo "  尚无（首次点歌时创建）"

echo ""
echo "=== 6. 语音缓存目录 ==="
ls /opt/dafeiyu/data/astrbot/audio/voice-cache/*.mp3 2>/dev/null | head -5 | sed 's/^/  /' || echo "  尚无"
