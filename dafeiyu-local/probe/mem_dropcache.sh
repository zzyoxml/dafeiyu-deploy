#!/bin/bash
set -u
echo "=== 等容器启动完成 ==="
for i in $(seq 1 10); do
  sleep 12
  R=$(docker ps --filter name=astrbot --format "{{.Status}}" 2>/dev/null)
  echo "  [${i}] $(date +%H:%M:%S)  $R"
  echo "$R" | grep -q "healthy" && break
done

echo ""
echo "=== 观察 dropcache 是否回收（3 分钟）==="
PREV=0
for i in $(seq 1 9); do
  C=$(awk '/^Cached:/{print int($2/1024)}' /proc/meminfo)
  A=$(awk '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo)
  D=$((C-PREV))
  echo "  [${i}] $(date +%H:%M:%S)  cached=${C}MB  avail=${A}MB  delta=${D}MB"
  PREV=$C
  sleep 20
done

echo ""
echo "=== 最终 ==="
free -h
awk '{
  if ($1=="MemTotal:") t=$2
  if ($1=="MemFree:") f=$2
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
} END {
  printf "  进程实际: %dMB   cache: %dMB\n", (t-f-c-b)/1024, (c+b)/1024
}' /proc/meminfo
</bash>
</invoke>
