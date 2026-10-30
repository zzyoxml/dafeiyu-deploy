#!/bash
set -u
echo "=== 1. 部署 ==="
cp <PROBE_DIR>/dsh-sing/main.py \
   /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py

echo ""
echo "=== 2. 语法 + 导入 ==="
docker exec astrbot python3 -c "
import ast,sys
p='/AstrBot/data/plugins/dsh-sing/main.py'
ast.parse(open(p,encoding='utf-8').read())
print('  语法 OK')
sys.path.insert(0,'/AstrBot')
import importlib.util
spec=importlib.util.spec_from_file_location('s',p)
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print('  ✅ 导入成功')
print('  类:', [n for n in dir(m) if n.endswith('Plugin')])
print('  _SHOWN:', type(m._SHOWN).__name__, '| _umo:', callable(m._umo))
" 2>&1 | tail -6

echo ""
echo "=== 3. 「选 N」正则匹配测试 ==="
docker exec astrbot python3 -c "
import re
P = r'^\s*(?:@\S+\s*)?(?:选|听|要|来)\s*(\d+)\s*\$'
for t in ['选 1','选1','听 2','来 3','@小鲸鱼 选 1','1','选 99']:
    m = re.search(P, t)
    print(f'  {t!r:18} → {\"序号 \"+m.group(1) if m else \"不匹配\"}')
" 2>&1 | tail -8

echo ""
echo "=== 4. 热重载 ==="
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
curl -s -m 30 -X POST "http://<PANEL_ADDR>/api/plugin/reload" \
  -H "Content-Type: application/json" -H "Authorization: Bearer \$JWT" \
  -d '{"name":"dsh-sing"}' 2>&1 | head -c 120
echo ""
