#!/usr/bin/env bash
# 状态检查（纯 ASCII 输出）
set -u
echo "=== Status ==="
d=$(systemctl is-active docker 2>/dev/null)
echo "  docker     : $d"
for n in napcat astrbot; do
  st=$(docker inspect "$n" --format '{{.State.Status}}' 2>/dev/null)
  hl=$(docker inspect "$n" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}-{{end}}' 2>/dev/null)
  printf '  %-10s : %s (%s)\n' "$n" "${st:-missing}" "$hl"
done
p=$(cat /root/anchor.pid 2>/dev/null)
if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
  echo "  anchor     : running (pid $p)"
else
  echo "  anchor     : DOWN"
fi
if [ -f /root/anchor.beat ]; then
  b=$(cut -d' ' -f1 /root/anchor.beat)
  age=$(( $(date +%s) - b ))
  echo "  heartbeat  : ${age}s ago"
fi
c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 http://127.0.0.1:6185/ 2>/dev/null)
echo "  webui 6185 : $c"
w=$(docker logs astrbot --since 10m 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -ac '适配器已连接')
echo "  ws connect : $w (last 10m)"
echo "  msgs today : $(docker logs napcat --since 24h 2>&1 | grep -ac '发送 ->')"