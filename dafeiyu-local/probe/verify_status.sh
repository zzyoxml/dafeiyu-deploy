#!/bin/bash
set -u
echo "=== 1. 热重载后插件状态 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "dsh-sing" | tail -4

echo ""
echo "=== 2. 确认权限与环境仍生效 ==="
docker exec astrbot python3 /tmp/check_sing.py 2>&1 | grep -E "GROUP|STATUS|locked" | head -5
docker exec astrbot sh -c "env | grep DSH_SING" | sort

echo ""
echo "=== 3. 模拟一次完整的状态写入（不改真实状态，只看文件格式）==="
cat > /tmp/sim_status.py <<'PYEOF'
import sys
sys.path.insert(0, "/AstrBot")
import importlib.util
spec = importlib.util.spec_from_file_location(
    "dsh_sing_main", "/AstrBot/data/plugins/dsh-sing/main.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# 直接测状态机
mod._CURRENT["song"] = "夜曲"
mod._step("demucs")
mod._status_write(event="start", mode="ai", seconds=30, title="夜曲-周杰伦")
print("  写入一条 start 记录后:")
print("    _read_last_status() =", mod._read_last_status(), "（start 不算结果，应 None）")

mod._step("send")
mod._status_write(event="ok", bytes=470000, file="sing-xxx.mp3")
print("  写入一条 ok 记录后:")
last = mod._read_last_status()
print("    最近结果 =", last)
PYEOF
docker cp /tmp/sim_status.py astrbot:/tmp/sim_status.py
docker exec astrbot python3 /tmp/sim_status.py 2>&1 | tail -10

echo ""
echo "=== 4. 看实际写出的状态文件 ==="
cat /opt/dafeiyu/data/astrbot/sing/status.jsonl 2>/dev/null | tail -5

echo ""
echo "=== 5. 清理模拟数据 ==="
rm -f /opt/dafeiyu/data/astrbot/sing/status.jsonl
echo "  已清理（真实任务会重新生成）"
