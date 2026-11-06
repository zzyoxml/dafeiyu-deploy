#!/bin/bash
set -u
echo "=== 1. dsh-sing 是否在加载列表 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "dsh-sing" | head -10
echo ""
echo "=== 2. 加载失败/错误 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "sing.*(fail|error|错误|失败)|无法加载" | tail -10
echo ""
echo "=== 3. 所有已加载插件数 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -c "Plugin .* by "
echo ""
echo "=== 4. 命令注册检查（搜唱歌）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "唱歌|搜歌|原唱|翻唱" | tail -10
echo ""
echo "=== 5. 插件目录实际内容 ==="
docker exec astrbot sh -c "ls -la /AstrBot/data/plugins/dsh-sing/"
echo ""
echo "=== 6. 尝试手工导入验证 ==="
cat > /tmp/try_import.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot/data/plugins")
try:
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    print("  ✅ 模块导入成功")
    print("  类:", [n for n in dir(mod) if "Plugin" in n or n == "Main"])
except Exception as e:
    import traceback
    print("  ❌ 导入失败:", type(e).__name__, e)
    traceback.print_exc()
PYEOF
docker cp /tmp/try_import.py astrbot:/tmp/try_import.py
docker exec astrbot python3 /tmp/try_import.py 2>&1 | tail -20
