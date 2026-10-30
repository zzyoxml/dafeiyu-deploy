#!/bin/bash
set -u
echo "=== 1. 部署（只复制文件，不重启）==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py
docker exec astrbot python3 /tmp/check_import2.py 2>&1 | tail -5

echo ""
echo "=== 2. 确认当前没有任务在跑（避免再次打断）==="
if ls /opt/dafeiyu/data/astrbot/sing/work/ 2>/dev/null | grep -q .; then
  echo "  ⚠ 有工作目录残留："
  ls /opt/dafeiyu/data/astrbot/sing/work/
else
  echo "  ✅ 工作目录为空，无任务在跑"
fi
echo ""
echo "  最近的产物:"
ls -lht /opt/dafeiyu/data/astrbot/audio/ 2>/dev/null | head -4

echo ""
echo "=== 3. 状态文件是否已存在 ==="
ls -la /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null || echo "  尚无（首次任务后生成）"

echo ""
echo "=== 4. 不重启，改用 AstrBot 热重载 ==="
echo "  尝试通过 WebUI API 重载插件"
curl -s -m 20 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(cat /tmp/astrbot_jwt 2>/dev/null || echo '')" \
  -d '{"name":"dsh-sing"}' 2>/dev/null | head -c 300 || echo "  (需要 JWT，跳过)"
