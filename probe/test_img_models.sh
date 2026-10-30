#!/usr/bin/env bash
# 专测 trae/multimodal_image_kimi-k2.5 和其他疑似生图模型
set -u
K="<你的OFM_KEY>"
B="http://<HOST_GATEWAY>:18901/v1"

for m in "trae/multimodal_image_kimi-k2.5" "trae/multimodal_image_kimi-k2.6" "trae/aquila" "trae/custom_model_gemini" "trae/custom_model_gpt-5"; do
  echo "===== $m ====="
  body=$(curl -s --noproxy "*" --max-time 120 -X POST "$B/chat/completions" \
    -H "Authorization: Bearer $K" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"画一只可爱的胖鲸鱼\"}],\"max_tokens\":1500}" 2>&1)
  if echo "$body" | grep -qE '"b64_json"|"image_url"|data:image|"images"|"multi_modai_content"'; then
    echo "  ✓✓✓ 返回图片数据！"
    echo "$body" | head -c 400; echo ""
    echo "$body" > /tmp/hit_$$.json
  elif echo "$body" | grep -q '"error"'; then
    echo "  ✗ $(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -c12-90)"
  else
    # 检查 content 是否含 markdown 图或 URL
    urls=$(echo "$body" | grep -oE 'https?://[^"\\ ]+\.(png|jpg|jpeg|webp)' | head -2)
    if [ -n "$urls" ]; then
      echo "  ✓ content 里有图片 URL: $urls"
    else
      txt=$(echo "$body" | python3 -c "import sys,json;d=json.load(sys.stdin);print((d['choices'][0]['message'].get('content') or '')[:60].replace(chr(10),' '))" 2>/dev/null)
      echo "  — 纯文字: $txt"
    fi
  fi
  echo ""
done
