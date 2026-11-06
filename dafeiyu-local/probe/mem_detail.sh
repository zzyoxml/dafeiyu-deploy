#!/bin/bash
set -u
echo "=== 1. WSL 版本 ==="
uname -r
echo ""
echo "  /mnt/c/Users/Administrator/.wslconfig 全文:"
echo "  ─────────"
cat /mnt/c/Users/Administrator/.wslconfig 2>/dev/null | sed 's/^/    /'
echo "  ─────────"

echo ""
echo "=== 2. 容器内 TOP 内存消费者 ==="
docker exec astrbot sh -c "ps aux --sort=-%mem | head -6 | awk '{printf \"    %-10s %5s%% %7sMB  %s\n\", \$1, \$4, int(\$6/1024), substr(\$11,1,50)}'" 2>&1

echo ""
echo "=== 3. AstrBot 里什么占大头（模块级）==="
docker exec astrbot python3 -c "
import sys
mods = sorted(sys.modules.items(), key=lambda kv: (len(kv[0]), kv[0]))
big = []
for name, m in mods:
    f = getattr(m, '__file__', None)
    if not f: continue
    try:
        import os
        sz = os.path.getsize(f)
        big.append((sz, name))
    except Exception: pass
big.sort(reverse=True)
for sz, n in big[:12]:
    print(f'    {sz//1024:6}KB  {n}')
" 2>&1 | tail -14

echo ""
echo "=== 4. SenseVoice 模型常驻内存多少 ==="
docker exec astrbot python3 -c "
import os
p='/proc/self/status'
for ln in open(p):
    if ln.startswith(('VmRSS','VmSize')):
        print('   ', ln.strip())
" 2>&1

echo ""
echo "=== 5. 有无 swap 使用（说明内存吃紧）==="
free -m | awk 'NR==3{printf "  swap: total=%sMB used=%sMB\n",$2,$3}'
docker exec astrbot sh -c "free -m | tail -1" 2>&1 | sed 's/^/  容器内: /'

echo ""
echo "=== 6. WSL 支持 autoMemoryReclaim 吗（看内核版本 ≥ 5.15.90）==="
uname -r | sed 's/^/  kernel: /'
