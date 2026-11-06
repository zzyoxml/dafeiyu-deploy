#!/bin/bash
set -u

echo "=== 1. 最终检查插件文件 ==="
ls -la /opt/dafeiyu/data/astrbot/plugins/dsh-sing/
echo ""
docker exec astrbot python3 /tmp/syntax_check.py 2>&1 || echo "  语法检查需重跑"

echo ""
echo "=== 2. 音频输出目录 ==="
mkdir -p /opt/dafeiyu/data/astrbot/audio
echo "  已创建 /AstrBot/data/audio"
echo ""
echo "=== 3. 工作目录 ==="
mkdir -p /opt/dafeiyu/data/astrbot/sing/work
echo "  已创建 sing/work"

echo ""
echo "=== 4. 重启 astrbot 加载插件 ==="
cd /opt/dafeiyu
docker compose restart astrbot 2>&1 | tail -2
for i in $(seq 1 30); do
  sleep 5
  h=$(docker inspect astrbot --format "{{.State.Health.Status}}" 2>/dev/null | tr -d "\r\n ")
  if [ "$h" = "healthy" ]; then echo "  ✅ 第 $((i*5))s healthy"; break; fi
done

echo ""
echo "=== 5. 插件加载日志 ==="
docker logs astrbot --tail 80 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "dsh-sing|sing|插件|plugin" | tail -15
