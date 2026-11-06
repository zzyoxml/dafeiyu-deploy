#!/bin/bash
set -u
echo "=== 1. 容器主进程内存构成 ==="
PID=$(docker exec astrbot sh -c "ls /proc | grep -E '^[0-9]+$' | head -50" 2>/dev/null)
docker exec astrbot python3 -c "
import glob, os, subprocess
best=[]
for d in glob.glob('/proc/[0-9]*'):
    pid=d.split('/')[-1]
    try:
        cmd=open(f'/proc/{pid}/cmdline','rb').read().decode('utf8','ignore').replace('\x00',' ').strip()
        rss=0
        for ln in open(f'/proc/{pid}/status'):
            if ln.startswith('VmRSS'): rss=int(ln.split()[1])
        if cmd and rss>5*1024:
            best.append((rss,pid,cmd[:60]))
    except Exception: pass
best.sort(reverse=True)
for rss,pid,cmd in best[:6]:
    print(f'  {rss//1024:6}MB  pid={pid:6}  {cmd}')
" 2>&1 | tail -8

echo ""
echo "=== 2. AstrBot 关键子系统内存（区分谁在涨）==="
docker exec astrbot python3 -c "
import os
# 只看主 python 进程
for d in os.listdir('/proc'):
    if not d.isdigit(): continue
    try:
        cl = open(f'/proc/{d}/cmdline','rb').read().decode('utf8','ignore')
        if 'main.py' in cl or ('python' in cl and 'astrbot' in cl):
            st = {}
            for ln in open(f'/proc/{d}/status'):
                if ln.startswith(('VmRSS','VmSize','VmSwap','RssAnon','RssFile')):
                    k,v = ln.split(':'); st[k.strip()]=int(v.split()[0])
            print(f'  pid={d}')
            for k,v in st.items():
                print(f'    {k:10} {v//1024:6}MB')
    except Exception: pass
" 2>&1 | tail -12

echo ""
echo "=== 3. 插件数量（每个插件都常驻）==="
docker exec astrbot sh -c "ls /AstrBot/data/plugins/ | wc -l" | xargs -I{} echo "  插件目录: {} 个"

echo ""
echo "=== 4. qq 进程（napcat）==="
docker exec napcat sh -c "cat /proc/1/status 2>/dev/null | grep -E 'VmRSS|VmSize'" 2>&1 | sed 's/^/  /'
for d in $(docker exec napcat sh -c "ls /proc | grep -E '^[0-9]+$'" 2>/dev/null | head -30); do
  R=$(docker exec napcat sh -c "grep VmRSS /proc/$d/status 2>/dev/null | awk '{print \$2}'" 2>/dev/null | tr -d '\r')
  [ -n "$R" ] && [ "$R" -gt 50000 ] 2>/dev/null && echo "  pid=$d ${R}KB"
done 2>/dev/null | head -5

echo ""
echo "=== 5. shared memory / tmpfs 占用 ==="
df -h | grep -E "tmpfs|shm" | sed 's/^/  /'
