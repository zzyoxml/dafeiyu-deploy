#!/bin/bash
set -u
echo "=== 收官快照 $(date '+%H:%M:%S') ==="
echo ""
echo "【曲库】"
docker exec astrbot python3 -c "
import sys; sys.path.insert(0,'/AstrBot')
import importlib.util
s=importlib.util.spec_from_file_location('s','/AstrBot/data/plugins/dsh-sing/main.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
st=m._cache_stats()
print(f\"  {st['count']}/{st['max']} 首，{st['bytes']//1048576}MB\")
d=m._cache_load()['entries']
for v in sorted(d.values(), key=lambda e:-e.get('last_used',0)):
    print(f\"    [{'AI' if v['mode']=='ai' else '原'}] {v['song']} {v['seconds']}s 复用{v.get('hits',0)}次\")
" 2>/dev/null | tail -6

echo ""
echo "【语音】"
echo "  缓存: $(ls /opt/dafeiyu/data/astrbot/audio/voice-cache/*.mp3 2>/dev/null | wc -l) 句"
echo "  venv edge-tts: $(docker exec astrbot /AstrBot/data/sing/venv/bin/python -c 'import edge_tts;print(edge_tts.__version__)' 2>/dev/null | tail -1)"
echo "  主环境 edge-tts: $(docker exec astrbot python3 -c 'import edge_tts;print(edge_tts.__version__)' 2>/dev/null | tail -1)（旧版，已由 venv 路径绕过）"

echo ""
echo "【三个插件状态】"
for p in dsh-sing dsh-voice dsh-voice-liuying dsh-reply-guard; do
  L=$(docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -c "Plugin $p .*by 大肥鱼" || true)
  echo "  $p: 加载记录 $L 次"
done

echo ""
echo "【无残留】"
echo "  work: $(find /opt/dafeiyu/data/astrbot/sing/work -maxdepth 1 -type d ! -path '*/work' 2>/dev/null | wc -l) 个"

echo ""
echo "【错误检查（最后 100 行）】"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | tail -100 | grep -cE "handle error|Traceback" | xargs -I{} echo "  异常数: {}"
