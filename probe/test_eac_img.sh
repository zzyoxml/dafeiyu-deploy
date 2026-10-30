#!/usr/bin/env bash
# 测 OFM EAC 协付渠道的模型能否画图
set -u
K="<你的OFM_KEY>"
B="http://<HOST_GATEWAY>:18901/v1"

echo "=== 1) 模型列表里的 EAC / 生图类模型 ==="
curl -s --noproxy "*" --max-time 20 -H "Authorization: Bearer $K" "$B/models" \
  | tr ',' '\n' | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//' \
  | grep -iE 'z-ai|gpt-oss|kimi-k2|deepseek-ai|image|dall|flux|seedream|cogview|kolors|diffus|draw' | sort -u

echo ""
echo "=== 2) EAC 渠道生图路由探测 ==="
for p in "images/generations" "images"; do
  c=$(curl -s --noproxy "*" --max-time 25 -o /tmp/eac.out -w '%{http_code}' -X POST "$B/$p" \
    -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
    -d '{"model":"z-ai/glm-5.3","prompt":"a fat whale","n":1,"size":"1024x1024"}' 2>&1)
  echo "  [$c] POST /v1/$p  body: $(head -c 160 /tmp/eac.out 2>/dev/null | tr -d '\n')"
done

echo ""
echo "=== 3) EAC 模型逐个实测：chat + 画图指令（找返回图片数据的）==="
for m in "z-ai/glm-5.3" "z-ai/glm-5.3-flash" "openai/gpt-oss-20b" "moonshotai/kimi-k2.6" "deepseek-ai/deepseek-v4.1-flash"; do
  body=$(curl -s --noproxy "*" --max-time 90 -X POST "$B/chat/completions" \
    -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"画一只胖鲸鱼\"}],\"modalities\":[\"image\",\"text\"],\"max_tokens\":600}" 2>&1)
  if echo "$body" | grep -qE '"b64_json"|"image_url"|data:image|"images"'; then
    echo "  ✓✓ $m  【返回了图片数据】"
    echo "$body" | head -c 300; echo ""
  elif echo "$body" | grep -q '"error"'; then
    echo "  ✗   $m  -> $(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -c12-70)"
  else
    txt=$(echo "$body" | python3 -c "import sys,json;d=json.load(sys.stdin);c=d['choices'][0]['message'];print(((c.get('content')) or '')[:40].replace(chr(10),' '))" 2>/dev/null)
    echo "  —   $m  纯文字: $txt"
  fi
done
