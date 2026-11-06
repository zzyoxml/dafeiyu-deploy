#!/bin/bash
set -u

echo "=== 1. 清理 temp 里的旧媒体文件（保留最近 2 小时）==="
BEFORE=$(du -sm /opt/dafeiyu/data/astrbot/temp 2>/dev/null | cut -f1)
find /opt/dafeiyu/data/astrbot/temp -type f -name 'media_*' -mmin +120 -delete 2>/dev/null
find /opt/dafeiyu/data/astrbot/temp -type f -name '*.wav'   -mmin +120 -delete 2>/dev/null
find /opt/dafeiyu/data/astrbot/temp -type f -name '*.mp3'   -mmin +120 -delete 2>/dev/null
find /opt/dafeiyu/data/astrbot/temp -type f -name '*.amr'   -mmin +120 -delete 2>/dev/null
AFTER=$(du -sm /opt/dafeiyu/data/astrbot/temp 2>/dev/null | cut -f1)
echo "  temp: ${BEFORE}MB -> ${AFTER}MB  (释放 $((BEFORE-AFTER))MB)"

echo ""
echo "=== 2. 立即回收 page cache ==="
BEFORE_MB=$(awk '/^MemFree:/{print int($2/1024)}' /proc/meminfo)
sync
echo 3 > /proc/sys/vm/drop_caches
sleep 2
AFTER_MB=$(awk '/^MemFree:/{print int($2/1024)}' /proc/meminfo)
CACHED=$(awk '/^Cached:/{print int($2/1024)}' /proc/meminfo)
echo "  MemFree: ${BEFORE_MB}MB -> ${AFTER_MB}MB"
echo "  剩余 Cached: ${CACHED}MB"

echo ""
echo "=== 3. 调整 swappiness（降低换页倾向）==="
echo "  原值: $(cat /proc/sys/vm/swappiness)"
echo 10 > /proc/sys/vm/swappiness
echo "  新值: $(cat /proc/sys/vm/swappiness)"
echo "  （运行期生效，重启后回 60；持久化需要写 sysctl.conf）"

echo ""
echo "=== 4. 结果 ==="
free -h
echo ""
awk '{
  if ($1=="MemTotal:") t=$2
  if ($1=="MemFree:") f=$2
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
} END {
  printf "  WSL 内: total=%dMB free=%dMB cache=%dMB\n", t/1024, f/1024, (c+b)/1024
}' /proc/meminfo
echo ""
echo "  容器 RSS:"
for c in astrbot napcat; do
  T=$(docker exec $c python3 -c "
import glob
s=0
for f in glob.glob('/proc/[0-9]*/status'):
    try:
        for ln in open(f):
            if ln.startswith('VmRSS'): s+=int(ln.split()[1]); break
    except Exception: pass
print(s//1024)" 2>/dev/null | tr -d '\r')
  echo "    $c: ${T}MB"
done
