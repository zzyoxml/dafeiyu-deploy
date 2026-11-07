#!/bin/bash
# 部署：画图插件「群友可用 + 5% 随机主动生图 + 概念图全群开放」
# 2026-11-07。幂等：重复执行不会重复追加 env 行。
set -u

ENV=/opt/dafeiyu/robot.env
PLUGIN=/opt/dafeiyu/data/astrbot/plugins/dsh-imagegen/main.py
SRC_WIN=/mnt/d/xml/dafeiyu/data/astrbot/plugins/dsh-imagegen/main.py
STAMP=$(date +%Y%m%d-%H%M%S)

echo "=== 1. 备份 ==="
cp -n "$ENV" "$ENV.bak-imgdraw-$STAMP" 2>/dev/null || true
cp -n "$PLUGIN" "$PLUGIN.bak-imgdraw-$STAMP" 2>/dev/null || true
echo "备份完成：$STAMP"

echo "=== 2. 同步插件源码（仓库 data/ 版本为基准）==="
cp "$SRC_WIN" "$PLUGIN"
python3 -m py_compile "$PLUGIN" || { echo "FAIL 插件语法错误，已停止"; exit 1; }
echo "插件已更新并语法校验通过"

echo "=== 3. 更新 robot.env ==="
# 通用幂等写入：存在则整行替换，不存在则追加
set_kv() {
  local k="$1" v="$2"
  if grep -q "^${k}=" "$ENV"; then
    sed -i "s|^${k}=.*|${k}=${v}|" "$ENV"
    echo "  $k=$v (替换)"
  else
    printf '\n%s=%s\n' "$k" "$v" >> "$ENV"
    echo "  $k=$v (追加)"
  fi
}

# 5% 随机主动生图（默认 0.05；显式写出便于别人照抄配置）
set_kv DSH_IMG_RANDOM_RATE 0.05
set_kv DSH_IMG_RANDOM_COOLDOWN 180
set_kv DSH_IMG_RANDOM_MIN_CHARS 6
set_kv DSH_IMG_RANDOM_MAX_CHARS 120
# 主动概念图：开 + 全群开放（去掉原来的 3 个群白名单）
set_kv DSH_IMG_CONCEPT_AUTO 1
set_kv DSH_IMG_CONCEPT_GROUPS ""
# 概念图默认只在普通唤醒链不准备回复时补充；保持原样即可，不改。

echo "=== 4. 生效检查（环境变量快照）==="
grep -E "^DSH_IMG_(RANDOM|CONCEPT)" "$ENV"

echo "=== 5. 重启 astrbot ==="
docker restart astrbot >/dev/null
for i in $(seq 1 20); do
  s=$(docker inspect -f '{{.State.Health.Status}}' astrbot 2>/dev/null)
  [ "$s" = "healthy" ] && break
  sleep 5
done
echo "health=$s"
docker logs astrbot --since 1m 2>&1 | grep -E "\[imagegen\]" | tail -10

echo "=== DONE ==="
