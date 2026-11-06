#!/bash
set -u
P=/opt/dafeiyu/data/astrbot/plugins/dsh-selfguard/main.py
echo "=== 355-380 行（taunt 分支）==="
sed -n '355,382p' "$P"
echo ""
echo "=== _IMPATIENT_REPLIES 和 _TAUNT_REPLIES 是否还被引用 ==="
grep -n "_IMPATIENT_REPLIES\|_TAUNT_REPLIES\|taunt" "$P" | head -20
