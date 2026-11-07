#!/bin/bash
# 只重建 astrbot（docker restart 不重读 env_file，见 compose 注释）。
# compose 会先对整份文件做变量插值，napcat 的 ACCOUNT=${NAPCAT_ACCOUNT:?...}
# 在 robot.env 里没配，会直接报错拦住 —— 这里从**当前 napcat 容器**里读出
# 实际登录的 QQ 号，作为进程环境变量临时喂给 compose，不改任何文件。
# --no-deps 保证 napcat 容器本身不被重建（它带着 noauth 补丁，重建会丢）。
set -u
cd /opt/dafeiyu

ACCT=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' napcat 2>/dev/null | sed -n 's/^ACCOUNT=//p' | head -1)
if [ -z "$ACCT" ]; then
  echo "WARN 读不到 napcat 的 ACCOUNT，回退用占位值（不影响 astrbot）"
  ACCT=0
fi
echo "NAPCAT_ACCOUNT(临时)=$ACCT"

echo "=== docker compose up -d --no-deps --force-recreate astrbot ==="
env NAPCAT_ACCOUNT="$ACCT" docker compose up -d --no-deps --force-recreate astrbot 2>&1 | tail -15
for i in $(seq 1 24); do
  s=$(docker inspect -f '{{.State.Health.Status}}' astrbot 2>/dev/null)
  [ "$s" = "healthy" ] && break
  sleep 5
done
echo "health=$s"
echo "=== 容器内 DSH_IMG 相关 env ==="
docker exec astrbot sh -c "tr '\000' '\n' < /proc/1/environ | grep -E 'DSH_IMG_(RANDOM|CONCEPT)'"
echo "=== 插件加载日志 ==="
docker logs astrbot --since 2m 2>&1 | grep "\[imagegen\] 已加载" | tail -2
