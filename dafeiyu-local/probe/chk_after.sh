#!/bin/bash
set -u
P=/opt/dafeiyu/data/astrbot/plugins/dsh-selfguard/main.py

echo "=== 1. 还有谁调用 choose_impatient_reply / choose_taunt_reply ==="
grep -n "choose_impatient_reply\|choose_taunt_reply\|_last_taunt_reply" "$P"

echo ""
echo "=== 2. 还有哪些地方 set_result（可能塞话术）==="
grep -n "set_result" "$P"

echo ""
echo "=== 3. 看看 320-360 行那段 set_result(new_text) 是什么 ==="
sed -n '320,360p' "$P"

echo ""
echo "=== 4. 确认没有残留的 set_result(reply) ==="
grep -n "set_result(reply)" "$P" || echo "  已无"
</bash>
</invoke>
