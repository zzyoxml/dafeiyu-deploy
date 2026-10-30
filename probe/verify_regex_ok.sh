#!/bin/bash
set -u
echo "=== 1. 确认 @filter.regex 真的能注册 handler ==="
cat > /tmp/verify_regex_ok.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print("  ✅ 模块导入成功（说明 @filter.regex 合法）")

# 检查 each method 是否被登记进 star handler 注册表
from astrbot.core.star.star_handler import star_handlers_registry
print()
print("  注册表里 dsh-sing 的 handler:")
found = 0
for md in star_handlers_registry:
    mod_name = getattr(md, "module_path", "") or ""
    if "dsh-sing" in str(mod_name) or "dsh_sing" in str(mod_name):
        found += 1
        fnames = [type(f).__name__ for f in getattr(md, "event_filters", [])]
        regexes = [getattr(f, "regex_str", "") for f in getattr(md, "event_filters", [])
                   if hasattr(f, "regex_str")]
        print(f"    {getattr(md,'handler_name','?')}: filters={fnames} regex={regexes}")
print(f"  共 {found} 个")
PYEOF
docker cp /tmp/verify_regex_ok.py astrbot:/tmp/verify_regex_ok.py
docker exec astrbot python3 /tmp/verify_regex_ok.py 2>&1 | tail -20

echo ""
echo "=== 2. 当前插件版本时间戳 ==="
docker exec astrbot sh -c "stat -c '%y  %s bytes' /AstrBot/data/plugins/dsh-sing/main.py"

echo ""
echo "=== 3. 是否有 pycache 旧版本干扰 ==="
docker exec astrbot sh -c "ls -la /AstrBot/data/plugins/dsh-sing/__pycache__/ 2>/dev/null | head -5"
