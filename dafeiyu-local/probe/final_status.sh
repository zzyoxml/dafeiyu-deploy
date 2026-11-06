#!/bin/bash
set -u
echo "=== 当前部署状态总览 ==="
echo ""
echo "[1] 插件加载"
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "Plugin dsh-sing" | tail -1
echo ""
echo "[2] 权限配置"
docker exec astrbot sh -c "env | grep DSH_SING_GROUP_ACCESS"
echo ""
echo "[3] 命令清单"
docker exec astrbot python3 -c "
import sys, importlib.util
sys.path.insert(0, '/AstrBot')
spec = importlib.util.spec_from_file_location('m','/AstrBot/data/plugins/dsh-sing/main.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
for n in dir(m.SingPlugin):
    if n.startswith('cmd_'):
        d = (getattr(m.SingPlugin, n).__doc__ or '').strip().splitlines()
        print('   ', d[0] if d else n)
"
echo ""
echo "[4] 工作目录状态"
if ls /opt/dafeiyu/data/astrbot/sing/work/ 2>/dev/null | grep -q .; then
  echo "  ⚠ 有残留:"; ls /opt/dafeiyu/data/astrbot/sing/work/
else
  echo "  ✅ 空闲"
fi
echo ""
echo "[5] 已产出语音"
ls -lht /opt/dafeiyu/data/astrbot/audio/*.mp3 2>/dev/null | head -3 || echo "  （还没有）"
echo ""
echo "[6] 状态记录"
cat /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null | tail -3 || echo "  （还没有）"
