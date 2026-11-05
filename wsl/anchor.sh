#!/usr/bin/env bash
# 大肥鱼 · WSL 内保活循环
#
# 【关键教训 2026-10-18】
# 反向 WS 的「连通性」不能只测 TCP 端口：
#   connect_ex(('astrbot', 6199)) == 0 只能说明端口有监听，
#   但 NapCat 的 WebSocket 握手仍可能 "Opening handshake has timed out"
#   （AstrBot 适配器还没加载完时就是这样）。
#   之前用 TCP 判定，一旦 AstrBot 重启就误判为"断线"，锚点于是每 20 秒
#   重启一次 napcat，把系统拖进「重启→不可用→再重启」的死循环。
#
# 现在改为读日志判定，并且**只在真的确认断线且持续 3 轮后才重启**。

set -u

BEAT=/root/anchor.beat
PIDF=/root/anchor.pid
LOGF=/root/keepalive.log

echo $$ > "$PIDF"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGF"
  if [ "$(stat -c%s "$LOGF" 2>/dev/null || echo 0)" -gt 2000000 ]; then
    tail -2000 "$LOGF" > "${LOGF}.tmp" && mv "${LOGF}.tmp" "$LOGF"
  fi
}

# 反向 WS 是否健康：看最近 3 分钟内 astrbot 有没有"适配器已连接"
ws_ok() {
  local n
  n=$(docker logs astrbot --since 3m 2>&1 \
      | sed 's/\x1b\[[0-9;]*m//g' \
      | grep -ac '适配器已连接')
  [ "${n:-0}" -ge 1 ] && return 0

  # 没有重连日志时，看 napcat 侧最近有没有 handshake 失败
  local bad
  bad=$(docker logs napcat --since 2m 2>&1 | grep -ac 'handshake has timed out')
  [ "${bad:-0}" -ge 2 ] && return 1

  # 都没有 => 视为正常（连接可能一直稳着，不会反复打日志）
  return 0
}

check_once() {
  local code="" running="0"

  if ! systemctl is-active --quiet docker; then
    log "docker 未运行，启动"
    systemctl start docker 2>/dev/null
    sleep 5
  fi

  running=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
  if [ "$running" -lt 2 ]; then
    log "容器数=$running，启动 napcat astrbot"
    docker start napcat astrbot >/dev/null 2>&1
    sleep 8
  fi

  # 容器存在但 astrbot 不健康时，不重启，只记录（重启会丢掉适配器连接）
  local h
  h=$(docker inspect astrbot --format '{{.State.Health.Status}}' 2>/dev/null)
  if [ "$h" = "unhealthy" ]; then
    log "astrbot unhealthy（观察中，不自动重启）"
  fi

  # ---- 反向 WS：连续 3 轮不健康才重启 napcat ----
  if ws_ok; then
    ws_fail=0
  else
    ws_fail=$((ws_fail + 1))
    log "反向 WS 疑似断开（连续 $ws_fail 轮）"
    if [ "$ws_fail" -ge 3 ]; then
      log "连续 3 轮断开，重启 napcat"
      docker restart napcat >/dev/null 2>&1
      ws_fail=0
      sleep 15
    fi
  fi

  # ---- 探头抑制复位 ----
  docker exec astrbot python3 -c "
import sqlite3, json
try:
    c = sqlite3.connect('/AstrBot/data/dsh_action.db')
    rows = c.execute('SELECT key, value FROM kv').fetchall()
    fixed = 0
    for k, v in rows:
        if 'action_groups' not in k:
            continue
        try:
            d = json.loads(v)
        except Exception:
            continue
        if not isinstance(d, dict):
            continue
        for gid, s in d.items():
            if isinstance(s, dict) and s.get('ignored', 0) > 1:
                s['ignored'] = 1
                fixed += 1
        if fixed:
            c.execute('UPDATE kv SET value=? WHERE key=?', (json.dumps(d, ensure_ascii=False), k))
    c.commit(); c.close()
    if fixed:
        print(f'[anchor] 探头抑制计数已复位 {fixed} 个群')
except Exception:
    pass
" 2>/dev/null | while read -r l; do [ -n "$l" ] && log "$l"; done

  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:6185/ 2>/dev/null)
  running=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
  printf '%s running=%s astrbot=%s health=%s ws_fail=%s\n' \
    "$(date +%s)" "$running" "${code:-000}" "${h:-none}" "$ws_fail" > "$BEAT"
}

ws_fail=0
log "WSL 内保活循环启动 (pid $$)"

while true; do
  check_once
  sleep 20
done