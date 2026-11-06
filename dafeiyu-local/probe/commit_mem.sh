#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 把 WSL 配置存进仓库（供他人参考）==="
mkdir -p docs
cp /mnt/c/Users/Administrator/.wslconfig docs/wslconfig.example 2>/dev/null
if [ -f docs/wslconfig.example ]; then
  echo "  ✅ docs/wslconfig.example"
  sed 's/^/    /' docs/wslconfig.example | head -8
else
  echo "  ❌ 复制失败"
fi

echo ""
echo "=== 2. 补 .gitignore（回收日志） ==="
if ! grep -q "mem-reclaim.log" .gitignore; then
  cat >> .gitignore <<'EOF'
data/astrbot/mem-reclaim.log
EOF
  echo "  已加"
fi

echo ""
echo "=== 3. 提交 ==="
git add probe/mem-reclaim.sh probe/dafeiyu-mem-reclaim.service \
        probe/dafeiyu-mem-reclaim.timer probe/install_mem_timer.sh \
        probe/mem_survey.sh probe/mem_detail.sh probe/mem_breakdown.sh \
        probe/mem_opt_check.sh probe/mem_reclaim_now.sh probe/mem_wslconfig.sh \
        probe/check_autostart.sh probe/check_sing.sh probe/check_venv.sh \
        probe/mem_bound.sh probe/mem_after.sh probe/mem_wait.sh \
        probe/mem_dropcache.sh probe/verify_mem_timer.sh \
        docs/wslconfig.example .gitignore 2>/dev/null

git status --porcelain | head -25 | sed 's/^/  /'

git commit -q -m "perf(mem): WSL 内存占用从 5.9G 降到 2.1G

任务管理器里 VmMemWSL 常年 5.9G，但实际业务只用了 1.9G，剩下 3.1G
是 Linux 的 page cache 抱着不放——WSL 不会主动还给 Windows。

三层处理：

1. 立即回收（一次性 -2.8G）
   清掉 temp 里 62 万 KB 的旧媒体文件，然后 drop_caches。

2. 配置层（docs/wslconfig.example）
   - memory=8GB, processors=4, swap=2GB（明确上限）
   - vmIdleTimeout=60（原 -1 永不放 VM）
   - [experimental] autoMemoryReclaim=dropcache + sparseVhd=true

   踩的坑：autoMemoryReclaim 必须放 [experimental] 段。
   放 [wsl2] 段会被忽略并报「无法识别」。

   但实测 gradual 和 dropcache 都不管用：cached 稳在 2609MB 不动。
   原因是这个机制只在「整个 VM 空闲」时触发，而本机 docker + systemd
   常驻，VM 永远不会空闲。所以第 3 层才是真正解决问题的。

3. 定时回收（真正有效）
   systemd timer 每 10 分钟跑 mem-reclaim.sh，三道守卫：
     - sing/work 为空（没在唱歌，demucs 是最大内存户）
     - 无 demucs/rvc 进程（只看 argv[0]，不匹配任意子串）
     - 1 分钟负载 < 0.5
   用 drop_caches=1（只丢 page cache）而非 3，避免下一条消息的插件
   import 变慢。

   实测首次 reclaimed 3548MB，之后 cache 低到 557MB 时自动 no-op，
   不会做无用功。

修过一个自伤 bug：守卫 2 原用 docker exec python3 -c 检测 demucs，
而检查脚本自己的 cmdline 里就含 'demucs' 字符串，于是永远匹配到自己、
永远 skip，一次都没回收过。改为读 /proc/*/cmdline 只比对 argv[0] 文件名。

实测数据（4 核 i5-10400）：
  AstrBot 进程 866MB（含 SenseVoice ONNX 常驻）
  NapCat/QQ    792MB
  page cache   557MB（回收后）
  合计         约 2.1GB" 2>&1 | tail -2

echo ""
echo "=== 4. 结果 ==="
git log --oneline | head -3 | sed 's/^/  /'
echo ""
echo "  文件: $(git ls-files | wc -l)   改动: $(git status --porcelain | wc -l)"
</bash>
</invoke>
