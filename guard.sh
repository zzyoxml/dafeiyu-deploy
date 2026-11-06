#!/usr/bin/env bash
# 大肥鱼 QQ 机器人 · Windows 侧守护
#
# 【2026-10-18 重构原因】
# 旧版每 15 秒执行一次 `wsl` 命令。WSL 3.0.3 每执行一次 wsl.exe 就 fork 一个
# wslhost.exe，父进程退出后不回收。实测 19 个 wslhost 里 17 个是孤儿，
# 孤儿累积到一定数量后 Windows 侧会主动终止 WSL 实例：
#   15:36:15 systemd-logind: The system will power off now!
#   15:36:25 WSL ERROR: systemctl poweroff did not terminate the instance
# 结果 docker 和两个容器全部停掉。旧版还跑出了两个实例互相抢重启。
#
# 【新设计】
#   WSL 内：/root/anchor.sh 常驻循环，每 20 秒巡检 docker/容器/反向WS/健康，
#           把结果写进 /root/anchor.beat。它自己保证自己活着。
#   Windows侧：只读心跳文件（经 \\wsl$\ 路径，不启动 wsl.exe），
#           心跳超过 120 秒没更新才调用 wsl 干预。正常情况下完全不碰 wsl.exe。
#
# 这样 wsl.exe 的调用频率从「每 15 秒一次」降到「只在下线时调一次」，
# wslhost 不再堆积，实例也就不会被 Windows 侧掐掉。
#
# 其余两层保持不变：
#   - LLM 网关转发（容器 → 172.17.144.1:18901 → 127.0.0.1:18900）
#   - 注册表 Run 项 → wscript → 无窗口启动

set -u

# 自身定位：不再硬编码 /d/xml/dafeiyu。
# 用 git bash 的 $BASH_SOURCE 反推出脚本所在目录，整个项目可以随意搬动。
# 注意 $(cd ... && pwd) 在 git bash 下得到的是 /d/... 的 POSIX 路径，
# 与写死的 /d/xml/dafeiyu 等价，无需再做盘符转换。
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$SELF_DIR"

LOG="$BASE/logs/guard.log"
LOCK="$BASE/logs/guard.lock"
HB_FILE="//wsl\$/Ubuntu-24.04/root/anchor.beat"   # 直读，不启动 wsl.exe
HB_STALE=120          # 心跳超过这个秒数算失联

# node 的位置仍来自那套外部工具（Our Free Model 运行时），
# 但用户名不再写死：按当前用户展开。
NODE_BIN="$HOME/AppData/Local/Our Free Model/runtime/node.exe"
LLM_FWD="$BASE/llm-forward.mjs"

mkdir -p "$BASE/logs" 2>/dev/null

# ---------------------------------------------------------------- 单实例锁
if [ -f "$LOCK" ]; then
  old=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$old" ] && [ "$old" != "$$" ] && kill -0 "$old" 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 已有 guard 在跑 (pid $old)，退出" >> "$LOG"
    exit 0
  fi
fi
echo "$$" > "$LOCK"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

cleanup() {
  [ "$(cat "$LOCK" 2>/dev/null)" = "$$" ] && rm -f "$LOCK"
  exit 0
}
trap cleanup EXIT INT TERM

# 需要动 wsl 时的统一入口：带超时，避免卡死整个循环
wsl_do() {
  timeout 45 wsl -d Ubuntu-24.04 -u root -- bash -c "$1" 2>/dev/null
}

# 确保 WSL 内锚点活着（只在这个函数里才会真正调 wsl.exe）
# 同时兜底检查 docker 服务和容器 —— 锚点自己会做，但它挂掉时就靠这里
ensure_anchor() {
  wsl_do '
    # docker 服务（曾经因为 shutdown 卡在 activating/deactivating）
    if ! systemctl is-active --quiet docker; then
      echo "[guard] docker 未运行，尝试启动" >> /root/keepalive.log
      systemctl reset-failed docker docker.socket containerd 2>/dev/null
      systemctl start containerd 2>/dev/null
      sleep 2
      systemctl start docker 2>/dev/null
      sleep 5
    fi

    # 锚点
    pid=$(cat /root/anchor.pid 2>/dev/null)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      echo "[guard] 锚点不在，拉起" >> /root/keepalive.log
      setsid /root/anchor.sh </dev/null >/dev/null 2>&1 &
      disown
      sleep 3
    fi
  '
}

log "Windows 侧守护已启动 (pid $$)"

fail_streak=0
restart_count=0        # 本轮心跳失联累计次数，用来限速
last_restart=0

while true; do
  now=$(date +%s)

  # --- 读心跳：直读 \\wsl$\ 路径，不 fork wsl.exe（不泄漏 wslhost）---
  beat=0
  if [ -r "$HB_FILE" ]; then
    beat=$(sed -n 's/^\([0-9]\{1,\}\).*/\1/p' "$HB_FILE" 2>/dev/null | head -1)
    beat=${beat:-0}
  fi
  if [ "$beat" -gt 0 ]; then
    age=$((now - beat))
  else
    age=9999
  fi

  if [ "$age" -le "$HB_STALE" ]; then
    # 心跳新鲜，完全不用碰 wsl.exe
    fail_streak=0
  else
    fail_streak=$((fail_streak + 1))
    log "心跳过期 ${age}s（连续 $fail_streak 次）"

    # ⚠️ 永不自动 `wsl --shutdown`。
    # 之前的版本在连续 3 次失败后执行 shutdown，结果把 docker 服务弄进
    # activating/deactivating 死循环（要手动清 docker.sock 才能恢复），
    # 而且 shutdown 本身会让所有会话和容器一起断掉 —— 比它要解决的问题更糟。
    # 现在只在「距上次尝试超过 90 秒」时才调一次 wsl 尝试拉起锚点，
    # 且最多连续尝试 6 次（约 9 分钟），之后只记日志等人工处理。
    if [ "$fail_streak" -le 6 ] && [ $((now - last_restart)) -ge 90 ]; then
      last_restart=$now
      log "尝试拉起 WSL 内锚点（第 $fail_streak 次）"
      ensure_anchor
    elif [ "$fail_streak" -gt 6 ]; then
      log "多次恢复失败，不再自动干预（需要人工检查 wsl）"
    fi
    sleep 10
  fi

  # --- LLM 网关转发（Windows 侧，与 wsl 无关）---
  if ! netstat -ano 2>/dev/null | grep -q ':18901 .*LISTENING'; then
    if [ -x "$NODE_BIN" ] && [ -f "$LLM_FWD" ]; then
      "$NODE_BIN" "$LLM_FWD" >>"$BASE/logs/llm-forward.log" 2>&1 &
      log "LLM 转发已重新拉起 (pid $!)"
    else
      log "FAIL 找不到 node 或 llm-forward.mjs"
    fi
  fi

  # 清理孤儿 wslhost（保持系统干净；只在数量偏多时做）
  n=$(tasklist 2>/dev/null | grep -ci 'wslhost' || echo 0)
  if [ "${n:-0}" -gt 6 ]; then
    log "wslhost 偏多($n)，清理孤儿"
    powershell -NoProfile -WindowStyle Hidden -Command "
      Get-CimInstance Win32_Process -Filter \"Name='wslhost.exe'\" |
      Where-Object { -not (Get-Process -Id \$_.ParentProcessId -ErrorAction SilentlyContinue) } |
      ForEach-Object { Stop-Process -Id \$_.ProcessId -Force -ErrorAction SilentlyContinue }
    " >/dev/null 2>&1
  fi

  sleep 30
done
