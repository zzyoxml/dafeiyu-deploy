#!/usr/bin/env bash
# 大肥鱼 QQ 机器人 · 一键启动（在 WSL 内跑，输出纯 ASCII 便于 cmd 显示）
set -u

ok()  { echo "    [OK] $1"; }
bad() { echo "    [!!] $1"; }

echo "[1/5] WSL / docker"
if ! systemctl is-active --quiet docker; then
  systemctl start containerd >/dev/null 2>&1
  sleep 2
  systemctl start docker >/dev/null 2>&1
  sleep 6
fi
if systemctl is-active --quiet docker; then
  ok "docker active"
else
  bad "docker NOT active (try: systemctl restart docker)"
fi

echo "[2/5] containers"
# 手动停止时 restart 策略被改成 no，启动时必须改回 always，
# 否则 Docker/WSL 重启后两个容器不会自己起来（2026-10-19 踩过）
docker update --restart=always napcat astrbot >/dev/null 2>&1
docker start napcat astrbot >/dev/null 2>&1
sleep 3
for n in napcat astrbot; do
  st=$(docker inspect "$n" --format '{{.State.Status}}' 2>/dev/null)
  [ "$st" = "running" ] && ok "$n running" || bad "$n $st"
done

echo "[3/5] anchor"
p=$(cat /root/anchor.pid 2>/dev/null)
if [ -z "$p" ] || ! kill -0 "$p" 2>/dev/null; then
  setsid /root/anchor.sh </dev/null >/dev/null 2>&1 &
  disown
  sleep 3
  ok "anchor started (pid $(cat /root/anchor.pid 2>/dev/null))"
else
  ok "anchor already running (pid $p)"
fi

echo "[4/5] waiting for AstrBot"
for i in $(seq 1 12); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 http://127.0.0.1:6185/ 2>/dev/null)
  if [ "$code" = "200" ]; then
    ok "AstrBot ready (${i}0s)"
    break
  fi
  echo "    ... ${i}0s (http=$code)"
  sleep 10
done

echo "[5/5] status"
docker ps --format '    {{.Names}} | {{.Status}}' 2>/dev/null
echo ""
echo "    AstrBot panel : http://localhost:6185"
echo "    NapCat  panel : http://localhost:6099"