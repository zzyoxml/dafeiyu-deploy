#!/bin/bash
set -u
echo "=== 1. 等 2 分钟让启动期 I/O 走完 ==="
for i in 1 2 3 4 5 6; do
  sleep 20
  C=$(awk '/^Cached:/{print int($2/1024)}' /proc/meminfo)
  A=$(awk '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo)
  echo "  [${i}] $(date +%H:%M:%S)  cached=${C}MB  available=${A}MB"
done

echo ""
echo "=== 2. 稳定后内存 ==="
free -h

echo ""
echo "=== 3. 容器 RSS ==="
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
echo "=== 4. 机器人运行日志确认 ==="
docker logs astrbot --since 180s 2>&1 | grep -iE "适配器已连接|Running on" | tail -2
</bash>
</invoke>
