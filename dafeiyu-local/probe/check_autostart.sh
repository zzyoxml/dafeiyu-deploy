#!/bin/bash
set -u
echo "=== 1. 服务重启策略（决定 shutdown 后能否自拉起）==="
docker inspect astrbot --format '  astrbot: restart={{.HostConfig.RestartPolicy.Name}}' 2>&1
docker inspect napcat  --format '  napcat:  restart={{.HostConfig.RestartPolicy.Name}}' 2>&1

echo ""
echo "=== 2. systemd 服务状态 ==="
systemctl is-enabled docker 2>&1 | xargs -I{} echo "  docker: {}"
systemctl is-active docker 2>&1 | xargs -I{} echo "  docker active: {}"

echo ""
echo "=== 3. 有无开机自启脚本 ==="
ls -la /opt/dafeiyu/_setup.sh 2>/dev/null | sed 's/^/  /'
systemctl list-unit-files 2>/dev/null | grep -iE "dafeiyu|astrbot|napcat" | sed 's/^/  /' || echo "  （无相关 systemd unit）"

echo ""
echo "=== 4. docker compose 的 restart 配置 ==="
grep -A2 -B1 "restart" /opt/dafeiyu/docker-compose.yml 2>/dev/null | sed 's/^/  /'

echo ""
echo "=== 5. 当前内存（shutdown 前）==="
free -h | head -2 | sed 's/^/  /'
awk '{
  if ($1=="MemTotal:") t=$2
  if ($1=="MemFree:") f=$2
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
} END {
  printf "  实际占用(不含cache): %dMB   cache: %dMB\n", (t-f-c-b)/1024, (c+b)/1024
}' /proc/meminfo
</bash>
</invoke>
