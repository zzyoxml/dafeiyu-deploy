#!/usr/bin/env bash
# C 方案验证 + 「模型原生支持画图」验证
set -u
K="<你的OFM_KEY>"
B="http://<HOST_GATEWAY>:18901/v1"
P="http://<HOST_GATEWAY>:12450"

echo "############ 一、Pollinations（免 key）############"
for mode in noproxy proxy; do
  if [ "$mode" = noproxy ]; then EXTRA='--noproxy *'; else EXTRA="-x $P"; fi
  U="https://image.pollinations.ai/prompt/cute%20fat%20whale?width=512&height=512&nologo=true&seed=42"
  code=$(curl -s $EXTRA --max-time 100 -o /tmp/p_$mode.bin -w '%{http_code}' "$U" 2>&1)
  sz=$(stat -c%s /tmp/p_$mode.bin 2>/dev/null || echo 0)
  echo "  [$mode] HTTP=$code size=${sz}B $(file -b /tmp/p_$mode.bin 2>/dev/null | cut -c1-50)"
done

echo ""
echo "############ 二、buddy 模型「原生画图」验证 ############"
echo "  （chat/completions + modalities:[image,text]）"
for m in "buddy/glm-5v-turbo" "buddy/glm-5.3" "trae/Doubao-Seed-2.1-Pro" "buddy/hy3-x" "buddy/minimax-m3" "buddy/kimi-k3-1"; do
  [ "$m" = "" ] && continue
  body=$(curl -s --noproxy "*" --max-time 70 -X POST "$B/chat/completions" \
    -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"画一只胖鲸鱼\"}],\"modalities\":[\"image\",\"text\"],\"max_tokens\":128}" 2>&1)
  # 只看是否带图片数据
  if echo "$body" | grep -qE '"b64_json"|"image_url"|data:image'; then
    echo "  ✓ $m  >>> 返回了图片数据！"
    echo "$body" | head -c 300
    echo ""
  else
    prev=$(echo "$body" | head -c 150 | tr -d '\n')
    echo "  ✗ $m  -> $prev"
  fi
done

echo ""
echo "############ 三、其他免 key 生图站 ############"
try() {
  local name="$1" url="$2" extra="${3:-}"
  code=$(curl -s $extra --max-time 60 -o /tmp/t.bin -w '%{http_code}' "$url" 2>&1)
  sz=$(stat -c%s /tmp/t.bin 2>/dev/null || echo 0)
  ft=$(file -b /tmp/t.bin 2>/dev/null | cut -c1-40)
  echo "  [$code ${sz}B] $name -> $ft"
}
try "loremflickr"     "https://loremflickr.com/512/512/whale" "--noproxy *"
try "picsum"          "https://picsum.photos/512/512" "--noproxy *"
try "pollinations.ai" "https://pollinations.ai/" "--noproxy *"
