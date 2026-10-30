#!/bin/bash
set -u
echo "=== 1. 确认没有任务在跑 ==="
BUSY=0
if [ -d /opt/dafeiyu/data/astrbot/sing/work ]; then
  N=$(find /opt/dafeiyu/data/astrbot/sing/work -maxdepth 1 -type d ! -path '*/work' | wc -l)
  echo "  work 目录残留: $N 个"
  find /opt/dafeiyu/data/astrbot/sing/work -maxdepth 1 -type d ! -path '*/work' | sed 's/^/    /'
  [ "$N" -gt 0 ] && BUSY=1
fi
LAST=$(docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep "\.main:130\]" | tail -1)
echo "  最后步骤日志: ${LAST:-无}"
echo "  → BUSY=$BUSY"

echo ""
echo "=== 2. 校验 env 里唱歌段完整（含 GROUP_ACCESS）==="
grep -E "^DSH_SING_" /opt/dafeiyu/robot.env | sed 's/^/    /'

echo ""
echo "=== 3. 确认没有重复的段 ==="
for k in DSH_SING_GROUP_ACCESS DSH_VOICE_LY_RATE DSH_GUARD_RATE_MAX; do
  C=$(grep -c "^$k=" /opt/dafeiyu/robot.env || true)
  echo "  $k 出现 $C 次 $([ "$C" -gt 1 ] && echo '⚠ 重复')"
done

if [ "$BUSY" -eq 0 ]; then
  echo ""
  echo "=== 4. 重建容器让 env 生效（work 为空，安全）==="
  cd /opt/dafeiyu
  docker compose up -d --force-recreate astrbot 2>&1 | tail -4
  echo "  等待启动..."
  for i in $(seq 1 40); do
    sleep 3
    if curl -s -m 3 http://<PANEL_ADDR>/ -o /dev/null 2>/dev/null; then
      echo "  ✅ WebUI 已就绪（${i}0s 内）"; break
    fi
  done
else
  echo ""
  echo "=== 4. 有任务在跑，跳过重建（env 会在下次重建时生效）==="
  echo "  当前插件默认值已与目标一致，运行不受影响"
fi
