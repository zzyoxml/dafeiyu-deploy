#!/usr/bin/env bash
# 找真正能用的免 key 生图渠道
set -u

echo "############ A. HuggingFace 匿名推理 ############"
for M in "black-forest-labs/FLUX.1-schnell" "stabilityai/stable-diffusion-xl-base-1.0" "runwayml/stable-diffusion-v1-5"; do
  code=$(curl -s --noproxy "*" --max-time 120 -o /tmp/hf.bin -w '%{http_code}' \
    -X POST "https://api-inference.huggingface.co/models/$M" \
    -H "Content-Type: application/json" \
    -d '{"inputs":"a cute chubby whale, chibi anime"}' 2>&1)
  sz=$(stat -c%s /tmp/hf.bin 2>/dev/null || echo 0)
  ft=$(file -b /tmp/hf.bin 2>/dev/null | cut -c1-30)
  echo "  [$code ${sz}B] $M -> $ft"
  if [ "$code" != "200" ]; then head -c 160 /tmp/hf.bin 2>/dev/null | tr -d '\n'; echo ""; fi
done

echo ""
echo "############ B. Pollinations 换主机名绕开限速 ############"
for H in image.pollinations.ai image-origin.pollinations.ai; do
  for SEED in 11 22; do
    code=$(curl -s --noproxy "*" --max-time 100 -o /tmp/pl.bin -w '%{http_code}' \
      "https://$H/prompt/whale%20chibi?width=512&height=512&nologo=true&seed=$SEED" 2>&1)
    sz=$(stat -c%s /tmp/pl.bin 2>/dev/null || echo 0)
    echo "  [$code ${sz}B] $H seed=$SEED"
  done
done

echo ""
echo "############ C. 检查是否有可用的本地上游（OFM 或别的） ############"
echo "  OFM 18900 上的 chat 是否还能用:"
curl -s --noproxy "*" --max-time 30 -X POST "http://<HOST_GATEWAY>:18901/v1/chat/completions" \
  -H "Authorization: Bearer <你的OFM_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"model":"buddy/hy3","messages":[{"role":"user","content":"说OK"}],"max_tokens":10}' 2>&1 | head -c 250
