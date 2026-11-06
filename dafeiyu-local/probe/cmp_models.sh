#!/usr/bin/env bash
# 对比 Pollinations 各免费模型画风（同一只胖鲸鱼）
set -u
OUT=/mnt/d/xml/dafeiyu/dafeiyu-local/probe
mkdir -p "$OUT"
P="a%20cute%20chubby%20blue%20whale%2C%20kawaii%2C%20simple%20background"

i=0
for M in flux turbo kontext sdxl; do
  i=$((i+1))
  echo "--- model=$M ---"
  code=$(curl -s --noproxy "*" --max-time 150 -o /tmp/cmp_$M.jpg -w '%{http_code}' \
    "https://image.pollinations.ai/prompt/$P?width=768&height=768&nologo=true&model=$M&seed=2024$i" 2>&1)
  sz=$(stat -c%s /tmp/cmp_$M.jpg 2>/dev/null || echo 0)
  echo "  HTTP=$code size=${sz}B"
  if [ "$code" = "200" ] && [ "$sz" -gt 5000 ]; then
    cp /tmp/cmp_$M.jpg "$OUT/cmp_$M.jpg"
    echo "  ✓ 已存 $OUT/cmp_$M.jpg"
  else
    head -c 150 /tmp/cmp_$M.jpg 2>/dev/null | grep -o '"code":"[^"]*"' || true
  fi
  sleep 46   # 免费额度 1 张/45 秒
done
echo "完成"
