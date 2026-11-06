#!/bin/bash
set -u
CFG=/mnt/c/Users/Administrator/.wslconfig

echo "=== 1. 备份现有配置 ==="
cp "$CFG" "$CFG.bak-mem-$(date +%Y%m%d%H%M%S)" 2>/dev/null && echo "  已备份"

echo ""
echo "=== 2. 当前配置 ==="
cat "$CFG" | sed 's/^/  /'

echo ""
echo "=== 3. 写新配置 ==="
cat > "$CFG" <<'EOF'
[wsl2]
# 用默认 NAT 模式 + localhostForwarding。
# 实测：mirrored 模式下 Windows 侧访问 WSL 的 127.0.0.1 超时，
# 而 NAT 模式的 localhostForwarding 可正常工作。
# 需要在 WSL 内访问 Windows 代理时才启用 autoProxy。
autoProxy=true

# ── 资源上限 ────────────────────────────────────────────
# 宿主 32G，给 WSL 8G 够用（实测真实占用约 1.9G，其余是 page cache）
memory=8GB
processors=4

# ── 内存回收（关键）──────────────────────────────────────
# autoMemoryReclaim=gradual：WSL 空闲时逐步把 page cache 还给 Windows。
# 不加这个的话，Linux 会一直抱着 cache 不放，任务管理器里 WSL 常年
# 显示 5-6G，而实际业务只用了不到 2G。
# 可选值：disabled（默认）| gradual（推荐）| dropcache（更激进）
autoMemoryReclaim=gradual

# 空闲多久后回收缓存。默认 0 = 每轮检查都回收。
# 设为 5 秒，避免频繁抖动。
# （单位秒，需要 WSL 2.0.0+）
# 注：这个键名是 sparseVhd 时代的写法，当前版本以 autoMemoryReclaim 为准

# ── 空闲超时 ────────────────────────────────────────────
# 原先是 -1（永不回收 VM）。改成 60 秒：所有 WSL 进程退出后
# 一分钟就关掉虚拟机，把 8G 预留内存完全还给 Windows。
# 注意：本机有 systemd 常驻服务（QQ/AstrBot），实际不会触发，
# 但如果哪天手动停掉服务，这个能兜底释放。
vmIdleTimeout=60

# ── swap ────────────────────────────────────────────────
# 默认 swap 是内存的 25%（2G）。保留，但降低换出倾向。
swap=2GB

# ── 内核参数：降低 page cache 与 swap 的倾向 ──────────────
# swappiness=10：只在真的没内存时才换出（默认 60 太激进）
# vfs_cache_pressure=50：更愿意回收 dentry/inode 缓存
# 这两项直接写进内核启动参数，比在 WSL 里手改 /proc 持久
kernelCommandLine="vm.swappiness=10 vm.vfs_cache_pressure=50"
EOF

echo "  已写入"

echo ""
echo "=== 4. 验证语法 ==="
cat "$CFG" | grep -vE "^#|^$" | sed 's/^/  /'

echo ""
echo "=== 5. 提示 ==="
echo "  配置需 wsl --shutdown 后重启才生效"
echo "  文件: $CFG"
</bash>
</invoke>
