#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 只提交实际存在的 ==="
ls -la probe/mem-reclaim.sh probe/dafeiyu-mem-reclaim.* probe/install_mem_timer.sh docs/wslconfig.example 2>/dev/null | sed 's/^/  /'

git add probe/mem-reclaim.sh probe/dafeiyu-mem-reclaim.service \
        probe/dafeiyu-mem-reclaim.timer probe/install_mem_timer.sh \
        docs/wslconfig.example .gitignore
echo ""
echo "  已暂存:"
git diff --cached --name-only | sed 's/^/    /'

echo ""
echo "=== 2. 提交 ==="
git commit -q -F - <<'MSGEOF'
perf(mem): WSL 内存占用 5.9G -> 约 2.1G

任务管理器里 VmMemWSL 常年 5.9G，实际业务只用了 1.9G，剩下 3.1G
是 Linux page cache 抱着不放——WSL 不会主动还给 Windows。

三层处理：

1. 立即回收（一次性 -2.8G）
   清掉 temp 里 62 万 KB 旧媒体文件，再 drop_caches。

2. 配置层（docs/wslconfig.example）
   memory=8GB / processors=4 / swap=2GB / vmIdleTimeout=60
   [experimental] autoMemoryReclaim=dropcache + sparseVhd=true

   坑：autoMemoryReclaim 必须写进 [experimental] 段。放 [wsl2] 段
   会被忽略且报「无法识别」。但实测 gradual 与 dropcache 都不管用
   ——cached 稳在 2609MB 不动。因为该机制只在「整个 VM 空闲」时触发，
   而本机 docker + systemd 常驻，VM 永不空闲。所以第 3 层才是解法。

3. 定时回收（真正有效）
   systemd timer 每 10 分钟跑 mem-reclaim.sh，三道守卫：
     - sing/work 为空（没在唱歌，demucs 是最大内存户）
     - 无 demucs/rvc 进程（只看 argv[0]，不匹配任意子串）
     - 1 分钟负载 < 0.5
   用 drop_caches=1（只丢 page cache）而非 3，避免下条消息的插件
   import 变慢。

   实测首次 reclaimed 3548MB，之后 cache 低到 557MB 时自动 no-op。

修过一个自伤 bug：守卫 2 原用 docker exec python3 -c 检测 demucs，
而检查脚本自己的 cmdline 里就含 'demucs' 字符串，于是一直匹配到自己、
一直 skip，一次都没真正回收过。改为读 /proc/*/cmdline 只比对 argv[0]。

实测构成（4 核 i5-10400）：
  AstrBot  866MB（含 SenseVoice ONNX 常驻）
  NapCat   792MB
  cache    557MB
  合计     约 2.1GB
MSGEOF
echo "  提交: $(git log --oneline -1)"

echo ""
echo "=== 3. 推送 ==="
GIT_SSH_COMMAND="ssh -i /root/.ssh/dafeiyu_deploy -o IdentitiesOnly=yes" \
  timeout 120 git push origin main:main 2>&1 | tail -5

echo ""
echo "=== 4. 同步确认 ==="
L=$(git rev-parse HEAD)
R=$(git ls-remote origin refs/heads/main 2>/dev/null | cut -f1)
echo "  本地 ${L:0:8} / 远端 ${R:0:8}"
[ "$L" = "$R" ] && echo "  ✅ 已同步" || echo "  ⚠ 不一致"
</bash>
</invoke>
