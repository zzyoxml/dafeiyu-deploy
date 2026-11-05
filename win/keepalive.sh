#!/usr/bin/env bash
# 大肥鱼 QQ 机器人 · 保活脚本（纯 bash 版）
#
# 由 run.sh / 计划任务调用。每 2 分钟执行一次：
#   1. 确保 WSL 里的 docker 服务在跑
#   2. 确保 napcat / astrbot 两个容器在跑（只在真的停了时才动）
#   3. 重新打 NapCat WebUI 凭据有效期补丁（容器重建后会丢）
#   4. 健康检查
#
# ⚠️ 绝不能对已在运行的容器执行 `docker compose up -d`，
#    那会重建容器并打断 QQ 登录态。

set -u

# 自动识别运行环境：
#   - 在 WSL 内跑（Linux 侧）：一切照常
#   - 在 Windows Git Bash 里跑：转交给 WSL 执行
if [ -d /proc/sys/fs/binfmt_misc ] && [ -f /etc/os-release ] && \
   grep -qi microsoft /proc/version 2>/dev/null; then
  IN_WSL=1
else
  IN_WSL=0
fi

if [ "$IN_WSL" = "0" ]; then
  # Windows 侧：把脚本内容转交 WSL
  payload=$(base64 -w0 "$0")
  wsl -d Ubuntu-24.04 -u root -- bash -c "echo $payload | base64 -d | bash"
  exit $?
fi

LOG=/mnt/d/xml/dafeiyu/logs/keepalive.log
mkdir -p "$(dirname "$LOG")" 2>/dev/null

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# 1. docker 服务
#
# ⚠️ 关键：绝对不要用 `systemctl start docker` 来"确保它在跑"。
#    `systemctl start` 对已经 active 的服务会先 stop 再 start（systemd 行为），
#    这会连带重启所有容器，导致浏览器侧间歇性 Network Error。
#    实测 10:11~10:13 就因此把 docker 连停启了两次。
#
#    正确做法：只在服务真正不存在（inactive/failed）时才启动，
#    并且用 systemctl start 之前先确认它不是 active。
if ! systemctl is-enabled docker >/dev/null 2>&1; then
  : # 服务未开机自启时交给下面的检查处理
fi

docker_state=$(systemctl is-active docker 2>/dev/null)
case "$docker_state" in
  active)
    : # 正常，不做任何动作
    ;;
  activating|deactivating)
    # 正在切换中，等它自己完成，不要插手
    sleep 10
    ;;
  *)
    # 真的挂了才启动
    systemctl start docker >/dev/null 2>&1
    sleep 10
    log "docker 从 ${docker_state} 状态恢复"
    ;;
esac

cd /opt/dafeiyu 2>/dev/null || { log "FAIL 找不到 /opt/dafeiyu"; exit 1; }

# 2. 容器状态
#    注意：dockerd 重启后，容器会停在 exited 状态，`restart: always` 不会自动拉起
#    （restart 策略由 dockerd 守护，dockerd 重启后需要手动 start）。
running=$(docker ps -q --filter "name=napcat" --filter "name=astrbot" | wc -l)
total=$(docker ps -aq --filter "name=napcat" --filter "name=astrbot" | wc -l)

if [ "$running" -lt 2 ]; then
  if [ "$total" -lt 2 ]; then
    docker compose up -d >/dev/null 2>&1
    log "容器不存在，已 compose up"
  else
    docker start napcat astrbot >/dev/null 2>&1
    log "容器已停止，已 start"
  fi
  # 容器启动需要时间（AstrBot 约 30~70 秒），等够再探活
  sleep 45
fi

# 3. NapCat 凭据有效期补丁（容器重建后需要重打）
patched=0
if docker ps -q --filter "name=napcat" | grep -q .; then
  cur=$(docker exec napcat sh -c \
    "grep -o 'MAX_CREDENTIAL_VALID_SECONDS = [0-9]*' /app/napcat/napcat.mjs | head -1" 2>/dev/null)
  case "$cur" in
    *"= 31536000") patched=1 ;;
    *)
      if [ -f /opt/dafeiyu/patches/napcat.mjs.patched ]; then
        docker cp /opt/dafeiyu/patches/napcat.mjs.patched napcat:/app/napcat/napcat.mjs >/dev/null 2>&1 \
          && patched=2 && log "NapCat 补丁已重新应用"
      fi
      ;;
  esac
fi

# 4. OneBot 反向 WS 连通性
#
# NapCat 作为 WS 客户端连 ws://astrbot:6199/ws。
# 它启动时如果 AstrBot 还没监听 6199，会 ECONNREFUSED 然后每 30 秒自己重连。
# 这里额外检查一次：端口通但连接没建起来时，重启 NapCat 触发立即重连。
ws_ok=0
if docker ps -q --filter "name=napcat" | grep -q . && \
   docker ps -q --filter "name=astrbot" | grep -q .; then
  if docker exec napcat sh -c \
      "python3 -c \"
import socket,sys
s=socket.socket(); s.settimeout(3)
sys.exit(0 if s.connect_ex(('astrbot',6199))==0 else 1)
\"" >/dev/null 2>&1; then
    ws_ok=1
  fi
fi

# 4.5 主动探头自我抑制复位
#
# dsh_action.py 的 withdraw 规则：
#     elif s['ignored'] >= 2 and now-s.get('last',0) < 1800:
#         reason = 'withdraw'
# 即「连续 2 次探头没人理」就自我闭嘴 30 分钟。
# 问题是 ignored 只在真的有人接话时才清零，冷清的群很容易卡在 2，
# 于是机器人看起来「又不会主动说话了」。
# 这里每轮巡检把它压到不超过 1，相当于给它留一次机会。
if docker ps -q --filter "name=astrbot" | grep -q .; then
  docker exec astrbot python3 -c "
import json, sqlite3, os
p = '/AstrBot/data/dsh_action.db'
if not os.path.exists(p):
    raise SystemExit(0)
con = sqlite3.connect(p)
cur = con.cursor()
cur.execute('SELECT gid, payload FROM action_groups')
rows = cur.fetchall()
changed = 0
for gid, payload in rows:
    s = json.loads(payload)
    if s.get('ignored', 0) > 1:
        s['ignored'] = 1
        cur.execute('INSERT OR REPLACE INTO action_groups VALUES(?,?)', (gid, json.dumps(s)))
        changed += 1
con.commit()
con.close()
print(changed)
" >/tmp/_ig 2>/dev/null
  ig_reset=$(cat /tmp/_ig 2>/dev/null || echo 0)
  [ "${ig_reset:-0}" != "0" ] && log "探头抑制计数已复位 $ig_reset 个群"
fi

# 5. 健康检查
a=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://127.0.0.1:6185/ 2>/dev/null)
[ -z "$a" ] && a=000
n=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://127.0.0.1:3001/ 2>/dev/null)
[ -z "$n" ] && n=000
w=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://127.0.0.1:6099/ 2>/dev/null)
[ -z "$w" ] && w=000

line="running=$running astrbot=$a napcat_ws=$n webui=$w patch=$patched revws=$ws_ok"
if [ "$running" = "2" ] && [ "$a" = "200" ] && [ "$patched" != "0" ] && [ "$ws_ok" = "1" ]; then
  log "OK   $line"
else
  log "WARN $line"
fi
echo "$line"