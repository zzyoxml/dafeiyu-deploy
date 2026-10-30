#!/usr/bin/env bash
# 用给定的 key 把所有可能的生图入口都探一遍
set -u
K="<你的OFM_KEY>"

probe() {
  local name="$1" url="$2" data="$3"
  local out code
  out=$(curl -s --noproxy "*" --max-time 45 -o /tmp/probe.out -w '%{http_code}' \
        -X POST "$url" \
        -H "Authorization: Bearer $K" \
        -H "Content-Type: application/json" \
        -d "$data" 2>&1)
  code="$out"
  body=$(head -c 220 /tmp/probe.out 2>/dev/null | tr -d '\n')
  printf '  [%s] %-46s -> %s\n' "$code" "$name" "$body"
}

echo "=== 候选 1: buddy 免费网关 ==="
B1="http://<HOST_GATEWAY>:18901/v1"
probe "images/generations"      "$B1/images/generations" '{"model":"dall-e-3","prompt":"cat","n":1,"size":"1024x1024"}'
probe "images/generations(hunyuan)" "$B1/images/generations" '{"model":"hunyuan-image","prompt":"cat"}'
probe "image/generations"       "$B1/image/generations"  '{"model":"dall-e-3","prompt":"cat"}'
probe "v1/images"               "$B1/images"             '{"model":"dall-e-3","prompt":"cat"}'

echo ""
echo "=== 候选 2: agnes（插件默认）==="
B2="https://apihub.agnes-ai.com/v1"
probe "agnes images/generations" "$B2/images/generations" '{"model":"agnes-image-2.5-flash","prompt":"a cute fat whale","n":1,"size":"1024x1024"}'

echo ""
echo "=== 候选 3: 智谱 CogView ==="
B3="https://open.bigmodel.cn/api/paas/v4"
probe "bigmodel cogview-3-flash" "$B3/images/generations" '{"model":"cogview-3-flash","prompt":"胖鲸鱼"}'

echo ""
echo "=== 候选 4: chat/completions 里带图片输出（有些网关这么走）==="
probe "buddy chat + image model" "$B1/chat/completions" '{"model":"gpt-image-1","messages":[{"role":"user","content":"draw a cat"}],"modalities":["image","text"]}'

echo ""
echo "=== 候选 5: buddy 模型列表里是否有 VL/生图专用 ==="
curl -s --noproxy "*" --max-time 15 -H "Authorization: Bearer $K" "$B1/models" \
  | tr ',' '\n' | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//' \
  | grep -iE 'image|dall|flux|seedream|cogview|sd|kolors|wanx|paint|diffus|gpt-image' \
  || echo "  无生图模型"
