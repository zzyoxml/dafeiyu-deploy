#!/usr/bin/env bash
# 逐个探测各家免费/在用生图模型的真实可用性
set -u
ZK="12633282e2d14211bb775836aa179e7b.Lf6EeTxVs5xVjjJY"

echo "########## 1. 智谱 bigmodel（当前在用）##########"
for M in cogview-4 cogview-3-flash cogview-x-3 glm-image; do
  r=$(curl -s --noproxy "*" --max-time 100 -X POST "https://open.bigmodel.cn/api/paas/v4/images/generations" \
    -H "Authorization: Bearer $ZK" -H "Content-Type: application/json" \
    -d "{\"model\":\"$M\",\"prompt\":\"一只胖鲸鱼\",\"size\":\"1024x1024\"}" 2>&1 \
    | python3 -c "import sys,json
try:
  d=json.load(sys.stdin)
  if 'data' in d and d['data']: print('OK  图片已出')
  elif 'error' in d:
    e=d['error']; print('ERR', str(e.get('code'))[:12], str(e.get('message'))[:60])
  else: print('?', str(d)[:60])
except Exception as ex: print('PARSE-FAIL')" 2>&1)
  printf "  %-18s %s\n" "$M" "$r"
  sleep 3
done

echo ""
echo "########## 2. 智谱是否免费额度可直接用（查计费）##########"
curl -s --noproxy "*" --max-time 30 -X POST "https://open.bigmodel.cn/api/paas/v4/chat/completions" \
  -H "Authorization: Bearer $ZK" -H "Content-Type: application/json" \
  -d '{"model":"cogview-3-flash","messages":[]}' 2>&1 | head -c 200
echo ""

echo ""
echo "########## 3. 其他国内免费生图 API ##########"
# 硅基流动（有免费模型）
r=$(curl -s --noproxy "*" --max-time 40 -X POST "https://api.siliconflow.cn/v1/images/generations" \
  -H "Content-Type: application/json" -d '{"model":"Kwai-Kolors/Kolors","prompt":"test"}' 2>&1 | head -c 130)
echo "  硅基流动(无key): $r"

echo ""
echo "########## 4. Pollinations 免 key（当前备用）##########"
for M in flux sdxl turbo; do
  c=$(curl -s --noproxy "*" --max-time 100 -o /tmp/pp_$M.jpg -w '%{http_code}' \
    "https://image.pollinations.ai/prompt/a%20fat%20whale?width=512&height=512&nologo=true&model=$M" 2>&1)
  s=$(stat -c%s /tmp/pp_$M.jpg 2>/dev/null || echo 0)
  printf "  %-8s HTTP=%s  %sB\n" "$M" "$c" "$s"
  sleep 46
done

echo ""
echo "########## 5. HF / 免 key 中转 ##########"
c=$(curl -s --noproxy "*" --max-time 30 -o /dev/null -w '%{http_code}' "https://api-inference.huggingface.co/models/black-forest-labs/FLUX.1-schnell" 2>&1)
echo "  HuggingFace 匿名: HTTP=$c"