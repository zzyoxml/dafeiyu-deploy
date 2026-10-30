#!/usr/bin/env bash
# 隔夜复测 Pollinations：额度是否重置
set -u

echo "=== 当前出口 IP ==="
curl -s --noproxy "*" --max-time 20 "https://api.ipify.org" 2>&1 | head -c 40
echo ""
echo ""

echo "=== 单次请求（1024x1024）==="
code=$(curl -s --noproxy "*" --max-time 150 -o /tmp/pl1.bin -w '%{http_code}' \
  "https://image.pollinations.ai/prompt/a%20cute%20chubby%20whale%20chibi%20anime?width=1024&height=1024&nologo=true&seed=888" 2>&1)
sz=$(stat -c%s /tmp/pl1.bin 2>/dev/null || echo 0)
ft=$(file -b /tmp/pl1.bin 2>/dev/null | cut -c1-45)
echo "  HTTP=$code  size=${sz}B  $ft"

if [ "$code" = "200" ] && [ "$sz" -gt 5000 ]; then
  echo "  ✓✓✓ 通了！"
  mkdir -p <PROBE_DIR>
  cp /tmp/pl1.bin <PROBE_DIR>/ok_whale.jpg
  echo "  已存到 Windows: probe/ok_whale.jpg"
else
  echo "  正文:"
  head -c 400 /tmp/pl1.bin 2>/dev/null
  echo ""
fi

echo ""
echo "=== 顺带测 Pollinations 免费文本模型（能不能白拿 LLM）==="
curl -s --noproxy "*" --max-time 45 -X POST "https://text.pollinations.ai/openai" \
  -H "Content-Type: application/json" \
  -d '{"model":"openai","messages":[{"role":"user","content":"说三个字"}],"max_tokens":20}' 2>&1 | head -c 300
