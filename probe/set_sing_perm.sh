#!/bin/bash
set -u
ENVF=/opt/dafeiyu/robot.env

echo "=== 1. 备份 ==="
cp "$ENVF" "${ENVF}.bak-sing-$(date +%Y%m%d-%H%M%S)"
echo "  已备份"

echo ""
echo "=== 2. 移除旧的唱歌配置（如果有）==="
grep -v "DSH_SING_" "$ENVF" > "${ENVF}.tmp" && mv "${ENVF}.tmp" "$ENVF"
echo "  已清理旧项"

echo ""
echo "=== 3. 追加唱歌配置 ==="
cat >> "$ENVF" <<'EOF'

# ---- dsh-sing 唱歌技能 ----
# owner=仅主人 / original=群友原唱 / ai=群友原唱+AI翻唱
DSH_SING_GROUP_ACCESS=ai
# 群友片段上限（CPU 上 30s 约 2-3 分钟；主人不受此限）
DSH_SING_MAX_SECONDS_GROUP=30
# 个人冷却（秒）
DSH_SING_COOLDOWN_USER=120
# 本群冷却（秒）
DSH_SING_COOLDOWN_GROUP=30
# 排队最长等待（秒）
DSH_SING_QUEUE_WAIT=180
EOF
echo "  已追加"

echo ""
echo "=== 4. 确认配置内容 ==="
grep "DSH_SING_" "$ENVF"

echo ""
echo "=== 5. 重建 astrbot 让 env_file 生效 ==="
cd /opt/dafeiyu
docker compose up -d --force-recreate astrbot 2>&1 | tail -3
for i in $(seq 1 40); do
  sleep 5
  h=$(docker inspect astrbot --format "{{.State.Health.Status}}" 2>/dev/null | tr -d "\r\n ")
  if [ "$h" = "healthy" ]; then echo "  ✅ 第 $((i*5))s healthy"; break; fi
done

echo ""
echo "=== 6. 容器内是否读到新环境变量 ==="
docker exec astrbot sh -c "env | grep DSH_SING_ | sort"

echo ""
echo "=== 7. 插件重新加载 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "Plugin dsh-sing" | tail -2
