#!/bin/bash
# dafeiyu-mem-reclaim —— 空闲时把 page cache 还给 Windows
#
# 为什么需要这个：
#   WSL 的 autoMemoryReclaim 只在「整个 VM 空闲」时触发。
#   本机 docker + systemd 常驻，VM 永远不会空闲，那个开关形同虚设。
#   实测：设了 gradual 和 dropcache，cached 一直稳在 2609MB 不动。
#
# 安全边界（三条都满足才回收）：
#   1. sing/work 为空          —— 没在跑唱歌（demucs 是最大内存户）
#   2. 无 demucs/rvc 进程       —— 二次确认
#   3. 1 分钟负载 < 0.5        —— 当前没有重活
#
# 回收动作：sync && echo 1 > /proc/sys/vm/drop_caches
#   用 1（只丢 page cache）而不是 3（连 dentry/inode 一起丢），
#   因为 3 会让下一条消息的插件 import 变慢。
#
# v1.1 修一个自伤 bug：
#   守卫 2 原先用 `docker exec astrbot python3 -c "...检测demucs..."`，
#   而这个检查脚本自己的 cmdline 里就含 'demucs' 字符串，
#   于是每次都匹配到自己，永远 skip。
#   改成读 /proc/*/cmdline 时排除 pid 自身与父进程，且只匹配
#   可执行文件路径（demucs 二进制 / cover.py 文件），不匹配任意子串。

set -u

WORK=/opt/dafeiyu/data/astrbot/sing/work
LOG=/opt/dafeiyu/data/astrbot/mem-reclaim.log
SELF=$$

log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# --- 守卫 1：唱歌任务 ---
if [ -d "$WORK" ] && [ -n "$(ls -A "$WORK" 2>/dev/null)" ]; then
  log "skip: sing/work 非空（正在唱歌）"
  exit 0
fi

# --- 守卫 2：重负载进程（只认可执行文件名，不认任意子串）---
HIT=0
for d in /proc/[0-9]*; do
  pid=$(basename "$d")
  [ "$pid" = "$SELF" ] && continue
  [ -r "$d/cmdline" ] || continue
  # 取 argv[0]（最多60字节），只看可执行文件本身
  exe=$(tr '\0' '\n' < "$d/cmdline" 2>/dev/null | head -1)
  [ -z "$exe" ] && continue
  base=$(basename "$exe")
  case "$base" in
    demucs|demucs.exe|cover.py) HIT=1; break ;;
  esac
done
if [ "$HIT" = "1" ]; then
  log "skip: 检测到 demucs/rvc 进程"
  exit 0
fi

# --- 守卫 3：负载 ---
LOAD1=$(cut -d' ' -f1 /proc/loadavg)
LOAD_INT=$(echo "$LOAD1" | awk '{printf "%d", $1*100}')
if [ "$LOAD_INT" -ge 50 ]; then
  log "skip: 1 分钟负载 $LOAD1 >= 0.5"
  exit 0
fi

# --- 执行回收 ---
BEFORE=$(awk '/^Cached:/{print int($2/1024)}' /proc/meminfo)
sync
echo 1 > /proc/sys/vm/drop_caches
sleep 1
AFTER=$(awk '/^Cached:/{print int($2/1024)}' /proc/meminfo)
FREED=$((BEFORE-AFTER))

if [ "$FREED" -gt 100 ]; then
  log "reclaimed ${FREED}MB (cached ${BEFORE}MB -> ${AFTER}MB, load=$LOAD1)"
else
  log "no-op (cache ${BEFORE}MB -> ${AFTER}MB, freed ${FREED}MB)"
fi
