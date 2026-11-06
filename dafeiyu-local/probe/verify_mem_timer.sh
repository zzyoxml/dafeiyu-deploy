#!/bin/bash
set -u
echo "=== 1. timer 已启用？ ==="
systemctl is-enabled dafeiyu-mem-reclaim.timer 2>&1 | sed 's/^/  /'
systemctl is-active dafeiyu-mem-reclaim.timer 2>&1 | sed 's/^/  /'

echo ""
echo "=== 2. 下次触发时间 ==="
systemctl list-timers dafeiyu-mem-reclaim.timer --no-pager 2>&1 | head -3 | sed 's/^/  /'

echo ""
echo "=== 3. 手动触发一次 timer，看是否真的跑了 ==="
systemctl start dafeiyu-mem-reclaim.service 2>&1
sleep 3
systemctl status dafeiyu-mem-reclaim.service --no-pager 2>&1 | head -8 | sed 's/^/  /'

echo ""
echo "=== 4. 日志 ==="
tail -3 /opt/dafeiyu/data/astrbot/mem-reclaim.log 2>/dev/null | sed 's/^/  /'

echo ""
echo "=== 5. 机器人是否正常 ==="
docker ps --format "  {{.Names}}: {{.Status}}"
docker logs astrbot --since 60s 2>&1 | grep -iE "适配器已连接|error|CRIT" | tail -3 | sed 's/^/  /'

echo ""
echo "=== 6. 最终内存 ==="
free -h | head -2 | sed 's/^/  /'
</bash>
</invoke>
