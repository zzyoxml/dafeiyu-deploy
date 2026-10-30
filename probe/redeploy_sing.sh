#!/bin/bash
set -u
echo "=== 1. 部署修正版 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
docker exec astrbot python3 /tmp/check_import2.py 2>&1 | tail -6

echo ""
echo "=== 2. 重启加载 ==="
cd /opt/dafeiyu
docker compose restart astrbot 2>&1 | tail -1
for i in $(seq 1 30); do
  sleep 5
  h=$(docker inspect astrbot --format "{{.State.Health.Status}}" 2>/dev/null | tr -d "\r\n ")
  if [ "$h" = "healthy" ]; then echo "  ✅ 第 $((i*5))s healthy"; break; fi
done

echo ""
echo "=== 3. dsh-sing 加载结果 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "dsh-sing" | tail -8

echo ""
echo "=== 4. 命令注册日志 ==="
docker logs astrbot --tail 100 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "唱歌|搜歌|原唱" | tail -8
