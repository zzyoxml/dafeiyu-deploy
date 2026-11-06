#!/bin/bash
set -u
echo "=== 1. WSL 内部内存总览 ==="
free -h
echo ""
echo "  明细（MB）:"
free -m | awk 'NR==2{printf "    total=%s used=%s free=%s shared=%s buff/cache=%s avail=%s\n",$2,$3,$4,$5,$6,$7}'

echo ""
echo "=== 2. 真正被进程吃掉的内存 TOP 12 ==="
ps aux --sort=-%mem | head -13 | awk '{printf "  %-8s %6s%% %8sMB  %s\n", $1, $4, int($6/1024), substr($11,1,60)}'

echo ""
echo "=== 3. 容器情况 ==="
docker stats --no-stream --format "  {{.Name}}: CPU={{.CPUPerc}} MEM={{.MemUsage}} ({{.MemPerc}})" 2>&1

echo ""
echo "=== 4. page cache 占用（可回收）==="
awk '{
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
  if ($1=="MemFree:") f=$2
  if ($1=="MemTotal:") t=$2
  if ($1=="SwapCached:") sc=$2
} END {
  printf "  MemTotal: %dMB\n  Cached:   %dMB\n  Buffers:  %dMB\n  MemFree:  %dMB\n", t/1024, c/1024, b/1024, f/1024
  printf "  可回收合计: %dMB\n", (c+b)/1024
}' /proc/meminfo

echo ""
echo "=== 5. WSL 配置现状 ==="
cat /mnt/c/Users/Administrator/.wslconfig 2>/dev/null || echo "  （无 .wslconfig，即用 WSL2 默认：最多用宿主 50% 内存）"
echo ""
echo "  宿主机总内存:"
grep MemTotal /proc/meminfo | awk '{printf "    WSL可见 %dMB\n", $2/1024}'

echo ""
echo "=== 6. swappiness 与回收倾向 ==="
cat /proc/sys/vm/swappiness | xargs -I{} echo "  vm.swappiness = {}"
cat /proc/sys/vm/vfs_cache_pressure | xargs -I{} echo "  vm.vfs_cache_pressure = {}"
docker exec astrbot sh -c "cat /proc/sys/vm/swappiness" 2>/dev/null | xargs -I{} echo "  容器内 swappiness = {}"
