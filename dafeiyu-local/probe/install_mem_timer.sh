#!/bin/bash
set -u

echo "=== 1. 部署脚本 ==="
cp /dev/null /dev/null 2>/dev/null || true
D=/opt/dafeiyu/probe
bash -n "$D/mem-reclaim.sh" 2>&1 && echo "  ✅ 语法 OK" || echo "  ❌ 语法错误"
chmod +x "$D/mem-reclaim.sh"
echo "  已 chmod +x"

echo ""
echo "=== 2. 立即试跑一次（验证守卫逻辑）==="
"$D/mem-reclaim.sh"
echo "  退出码: $?"
echo ""
echo "  日志:"
tail -3 /opt/dafeiyu/data/astrbot/mem-reclaim.log 2>/dev/null | sed 's/^/    /'

echo ""
echo "=== 3. 内存变化 ==="
free -h | head -2 | sed 's/^/  /'
awk '{
  if ($1=="MemTotal:") t=$2
  if ($1=="MemFree:") f=$2
  if ($1=="Cached:") c=$2
  if ($1=="Buffers:") b=$2
} END {
  printf "  进程实际: %dMB   cache: %dMB   free: %dMB\n", (t-f-c-b)/1024, (c+b)/1024, f/1024
}' /proc/meminfo

echo ""
echo "=== 4. 装 systemd timer ==="
cp "$D/dafeiyu-mem-reclaim.service" /etc/systemd/system/ 2>/dev/null
cp "$D/dafeiyu-mem-reclaim.timer"   /etc/systemd/system/ 2>/dev/null
systemctl daemon-reload
systemctl enable --now dafeiyu-mem-reclaim.timer 2>&1 | tail -3 | sed 's/^/  /'

echo ""
echo "=== 5. timer 状态 ==="
systemctl list-timers dafeiyu-mem-reclaim.timer --no-pager 2>&1 | head -3 | sed 's/^/  /'
</script>
</invoke>
