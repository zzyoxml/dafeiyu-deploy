#!/bin/bash
set -u
ENVFILE=/opt/dafeiyu/robot.env
cp "$ENVFILE" "${ENVFILE}.bak-dedup-$(date +%H%M%S)"

echo "=== 1. 去重：保留最后一次出现的值 ==="
python3 - <<'PYEOF'
import pathlib
p = pathlib.Path("/opt/dafeiyu/robot.env")
lines = p.read_text(encoding="utf-8").splitlines(keepends=True)

last_idx = {}
for i, ln in enumerate(lines):
    s = ln.strip()
    if s.startswith("DSH_") and "=" in s:
        last_idx[s.split("=", 1)[0]] = i

out, dropped = [], []
for i, ln in enumerate(lines):
    s = ln.strip()
    if s.startswith("DSH_") and "=" in s:
        k = s.split("=", 1)[0]
        if last_idx[k] != i:
            dropped.append(f"{k}={s.split('=',1)[1]}")
            continue
    out.append(ln)

p.write_text("".join(out), encoding="utf-8")
print(f"  删掉 {len(dropped)} 个重复行")
for d in dropped:
    print("    -", d[:60])
PYEOF

echo ""
echo "=== 2. 去重后校验 ==="
for k in DSH_SING_GROUP_ACCESS DSH_SING_CACHE_MAX DSH_VOICE_LY_RATE DSH_GUARD_RATE_MAX; do
  echo "  $k = $(grep "^$k=" "$ENVFILE" | tail -1 | cut -d= -f2-)  (出现 $(grep -c "^$k=" "$ENVFILE") 次)"
done
echo "  总 DSH_ 变量数: $(grep -c '^DSH_' "$ENVFILE")"
