#!/bin/bash
set -u
echo "════════ 内存优化最终结果 ════════"
echo ""
echo "【WSL 内部】"
free -h
echo ""
awk '{
  if ($1=="MemTotal:") t=$2
  if ($1=="MemFree:") f=$2
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
} END {
  printf "  进程实际: %dMB\n", (t-f-c-b)/1024
  printf "  page cache: %dMB\n", (c+b)/1024
  printf "  空闲: %dMB\n", f/1024
}' /proc/meminfo

echo ""
echo "【容器占用】"
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
  echo "  $c: ${T}MB"
done

echo ""
echo "【自动回收 timer】"
systemctl list-timers dafeiyu-mem-reclaim.timer --no-pager 2>&1 | sed -n '2p' | sed 's/^/  /'
echo "  历史:"
tail -4 /opt/dafeiyu/data/astrbot/mem-reclaim.log 2>/dev/null | sed 's/^/    /'

echo ""
echo "【机器人状态】"
docker ps --format "  {{.Names}}: {{.Status}}"
docker logs astrbot --since 300s 2>&1 | grep -cE "ERROR|CRIT" | xargs -I{} echo "  近 5 分钟报错: {} 条"

echo ""
echo "【配置】"
grep -vE "^#" /mnt/c/Users/Administrator/.wslconfig 2>/dev/null | grep -vE "^$" | sed 's/^/  /'
</bash>
</invoke>
