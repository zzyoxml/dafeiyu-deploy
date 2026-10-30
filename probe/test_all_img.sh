#!/usr/bin/env bash
# 对 AstrBot 里配的 15 个 model 逐个实测：能不能出图
set -u
K="<你的OFM_KEY>"
B="http://<HOST_GATEWAY>:18901/v1"
OUT=/tmp/imgtest
mkdir -p $OUT

MODELS="
buddy/hy3
buddy/deepseek-v4.1-flash
buddy/hy3-x
space-bunny-free
beam-free
buddy/deepseek-v4-flash
buddy/glm-5.3-flash
cohere/north-mini-code:free
deepseek-v4.1-flash-free
glm-5.3-flash-free
kilo-auto/free
longcat-2.5-preview-free
jev-1.13-free
buddy/deepseek-v4-pro
xingchen-agi/xing4.0-29b-a4b:free
"

echo "############ 方式1: chat/completions + modalities:[image,text] ############"
for m in $MODELS; do
  body=$(curl -s --noproxy "*" --max-time 60 -X POST "$B/chat/completions" \
    -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"画一只胖鲸鱼\"}],\"modalities\":[\"image\",\"text\"],\"max_tokens\":100}" 2>&1)

  if echo "$body" | grep -qE '"b64_json"|"image_url"|data:image'; then
    echo "  ✓✓ $m  【出图了】"
    echo "$body" | head -c 250; echo ""
  elif echo "$body" | grep -q '"error"'; then
    err=$(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -c12-80)
    echo "  ✗   $m  err: $err"
  else
    txt=$(echo "$body" | python3 -c "import sys,json;d=json.load(sys.stdin);print((d['choices'][0]['message'].get('content') or '')[:50])" 2>/dev/null || echo "?")
    echo "  —   $m  文字回复: $txt"
  fi
done

echo ""
echo "############ 方式2: 找有没有 images/generations 路由 ############"
for p in images/generations images/edits generations images; do
  c=$(curl -s --noproxy "*" --max-time 20 -o /dev/null -w '%{http_code}' -X POST "$B/$p" \
    -H "Authorization: Bearer $K" -H "Content-Type: application/json" -d '{}' 2>&1)
  echo "  [$c] POST /v1/$p"
done
