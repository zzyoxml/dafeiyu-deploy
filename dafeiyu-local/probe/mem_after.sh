#!/bin/bash
set -u
echo "=== 1. 容器状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "=== 2. 内存现状 ==="
free -h

echo ""
echo "=== 3. 真实占用（去掉 cache）vs cache ==="
awk '{
  if ($1=="MemTotal:") t=$2
  if ($1=="MemFree:") f=$2
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
} END {
  printf "  进程实际占用: %dMB\n", (t-f-c-b)/1024
  printf "  page cache:   %dMB\n", (c+b)/1024
  printf "  空闲:         %dMB\n", f/1024
}' /proc/meminfo

echo ""
echo "=== 4. autoMemoryReclaim 是否在工作（观察 30 秒）==="
for i in 1 2 3 4; do
  C=$(awk '/^Cached:/{print int($2/1024)}' /proc/meminfo)
  F=$(awk '/^MemFree:/{print int($2/1024)}' /proc/meminfo)
  echo "  [$i] cached=${C}MB  free=${F}MB"
  sleep 8
done

echo ""
echo "=== 5. 机器人功能确认 ==="
docker logs astrbot --since 120s 2>&1 | grep -iE "OneBot|适配器已连接|SenseVoice|Selected" | tail -4

echo ""
echo "=== 6. 两个容器 RSS ==="
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
