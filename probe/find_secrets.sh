#!/bin/bash
set -u
echo "=== robot.env 里所有非空值的变量（找漏网密钥）==="
grep -E "^[A-Z_]+=.+" /opt/dafeiyu/robot.env | while IFS='=' read -r k v; do
  # 看值像不像密钥：长度>16 且含字母数字混合
  LEN=${#v}
  if [ "$LEN" -gt 16 ]; then
    echo "  $k  (长度 $LEN)  ${v:0:8}…"
  fi
done

echo ""
echo "=== 特别检查：包含 key/token/cookie/secret 的变量 ==="
grep -iE "KEY|TOKEN|COOKIE|SECRET|PASSWORD|CREDENTIAL" /opt/dafeiyu/robot.env | grep -vE "^#" | while IFS='=' read -r k v; do
  printf "  %-30s = %s\n" "$k" "${v:0:12}…"
done
