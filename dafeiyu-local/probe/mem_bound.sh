#!/bin/bash
set -u
echo "=== 1. 唱歌任务的内存痕迹（历史 status.jsonl）==="
S=/opt/dafeiyu/data/astrbot/sing/status.jsonl
if [ -f "$S" ]; then
  echo "  记录数: $(wc -l < $S)"
  tail -3 "$S" | cut -c1-120 | sed 's/^/    /'
else
  echo "  无 status.jsonl"
fi

echo ""
echo "=== 2. 唱歌目录当前是否有任务在跑 ==="
ls -1 /opt/dafeiyu/data/astrbot/sing/work 2>/dev/null | head -5 | sed 's/^/  /'
N=$(ls -1 /opt/dafeiyu/data/astrbot/sing/work 2>/dev/null | wc -l)
echo "  work 目录: $N 项（0 = 空闲，这是判断能否安全回收的旗标）"

echo ""
echo "=== 3. demucs 实测峰值（用一段 10 秒音频快速测）==="
if [ -f /opt/dafeiyu/data/astrbot/sing/venv/bin/python ] && \
   [ -d /opt/dafeiyu/data/astrbot/sing/rvc ]; then
  echo "  venv 与 rvc 都在，可测"
else
  echo "  缺 venv/rvc，跳过实测"
fi

echo ""
echo "=== 4. 当前负载（判断是否空闲）==="
cat /proc/loadavg | sed 's/^/  /'
echo "  CPU 核心: $(nproc)"
awk '/^cpu /{idle=$5; total=0; for(i=2;i<=11;i++) total+=$i; printf "  idle 占比: %.1f%%\n", idle*100/total}' /proc/stat

echo ""
echo "=== 5. 可用于回收的判定条件 ==="
echo "  (a) sing/work 为空"
echo "  (b) 最近 5 分钟无 docker exec 的 RVC/demucs 进程"
docker exec astrbot python3 -c "
import glob, os
hits=[]
for f in glob.glob('/proc/[0-9]*/cmdline'):
    try:
        c=open(f,'rb').read().decode('utf8','ignore').replace('\x00',' ')
        if any(k in c for k in ('demucs','cover.py','rvc')):
            hits.append(c[:60])
    except Exception: pass
print(f'  当前 RVC/demucs 进程: {len(hits)}')
for h in hits[:3]: print('    '+h)
" 2>&1 | tail -4
</script>
</invoke>
