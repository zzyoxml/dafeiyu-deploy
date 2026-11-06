#!/bin/bash
set -u
echo "=== 1. 各容器真实 RSS 合计 ==="
for c in astrbot napcat; do
  T=$(docker exec $c python3 -c "
import glob
s=0
for f in glob.glob('/proc/[0-9]*/status'):
    try:
        for ln in open(f):
            if ln.startswith('VmRSS'):
                s+=int(ln.split()[1]); break
    except Exception: pass
print(s//1024)
" 2>/dev/null | tr -d '\r')
  echo "  $c: ${T}MB"
done

echo ""
echo "=== 2. AstrBot 插件启用情况 ==="
docker exec astrbot python3 -c "
import json
try:
    d=json.load(open('/AstrBot/data/plugins.json', encoding='utf-8'))
    ps = d if isinstance(d,list) else d.get('plugins',[])
    print(f'  plugins.json: {len(ps)} 条')
except Exception as e:
    print('  读取失败:', e)
" 2>&1 | tail -4

echo ""
echo "=== 3. /dev/shm 占用 ==="
du -sh /dev/shm 2>/dev/null | sed 's/^/  /'
docker inspect astrbot --format '  astrbot shm-size: {{.HostConfig.ShmSize}}' 2>&1
docker inspect napcat  --format '  napcat  shm-size: {{.HostConfig.ShmSize}}' 2>&1

echo ""
echo "=== 4. 磁盘占用（page cache 来源）==="
du -sh /opt/dafeiyu/data/astrbot/temp 2>/dev/null | sed 's/^/  temp: /'
du -sh /opt/dafeiyu/data/astrbot/sing  2>/dev/null | sed 's/^/  sing: /'
du -sh /opt/dafeiyu/data/astrbot       2>/dev/null | sed 's/^/  总计: /'

echo ""
echo "=== 5. dirty / 回写 ==="
awk '/^Dirty:/{printf "  dirty %dMB\n",$2/1024}' /proc/meminfo
awk '/^Writeback:/{printf "  回写中 %dMB\n",$2/1024}' /proc/meminfo

echo ""
echo "=== 6. 手动 drop_caches 能回收多少（先看，不执行）==="
awk '{
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
} END { printf "  当前可回收: %dMB\n", (c+b)/1024 }' /proc/meminfo
echo "  （执行 sync; echo 3 > /proc/sys/vm/drop_caches 可立即释放）"
