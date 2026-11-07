#!/bin/bash
# 验证随机生图 / 概念图改动在容器内生效
echo "=== 1. 容器内源码含新代码 ==="
docker exec astrbot python3 - <<'PYEOF'
p = "/AstrBot/data/plugins/dsh-imagegen/main.py"
s = open(p, encoding="utf-8").read()
checks = {
    "5% 默认概率": 'DSH_IMG_RANDOM_RATE", "0.05"' in s,
    "random.random 掷骰": "random.random() >= RANDOM_DRAW_RATE" in s,
    "random_draw 钩子": "async def random_draw" in s,
    "概念图全群通配": '"*" not in CONCEPT_GROUPS' in s,
}
for k, v in checks.items():
    print(("  OK   " if v else "  FAIL ") + k)
assert all(checks.values()), "有检查项未通过"
PYEOF

echo "=== 2. 运行环境 ==="
docker exec astrbot sh -c "tr '\000' '\n' < /proc/1/environ | grep -E 'DSH_IMG_(RANDOM_RATE|CONCEPT_AUTO|CONCEPT_GROUPS)'"

echo "=== 3. 启动后有无异常 ==="
docker logs astrbot --since 3m 2>&1 | grep -iE "imagegen.*(error|异常|traceback)|Traceback" | tail -8 || echo "  无异常"

echo "=== 4. 两个容器状态 ==="
docker ps --format '{{.Names}} {{.Status}}'
