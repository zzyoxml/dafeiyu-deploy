#!/usr/bin/env bash
# Pollinations 换出口 IP + 换端点再试
set -u
U="https://image.pollinations.ai/prompt/cute%20chubby%20whale%20chibi?width=1024&height=1024&nologo=true&seed=123"

echo "=== 1) 走 sing-box 代理（换出口 IP）==="
code=$(curl -s -x http://172.17.144.1:12450 --max-time 120 -o /tmp/a.jpg -w '%{http_code}' "$U" 2>&1)
sz=$(stat -c%s /tmp/a.jpg 2>/dev/null || echo 0)
echo "  HTTP=$code size=${sz}B  $(file -b /tmp/a.jpg 2>/dev/null | cut -c1-40)"
if [ "$code" = "200" ]; then cp /tmp/a.jpg /mnt/d/xml/dafeiyu/dafeiyu-local/probe/ok_proxy.jpg; fi
head -c 200 /tmp/a.jpg 2>/dev/null | grep -o '"code":"[^"]*"' || true

echo ""
echo "=== 2) 代理连通性确认 ==="
curl -s -x http://172.17.144.1:12450 --max-time 20 -o /dev/null \
  -w "  ipify: %{http_code}\n" "https://api.ipify.org?format=json" 2>&1
curl -s -x http://172.17.144.1:12450 --max-time 20 "https://api.ipify.org?format=json" 2>&1 | head -c 100
echo ""
echo "  直连出口 IP:"
curl -s --noproxy "*" --max-time 20 "https://api.ipify.org?format=json" 2>&1 | head -c 100
echo ""

echo ""
echo "=== 3) 新版端点（image-origin / v1/images）==="
for u in \
  "https://image-origin.pollinations.ai/prompt/whale?width=512&height=512&nologo=true&seed=5" \
  "https://pollinations.ai/p/whale" ; do
  code=$(curl -s --noproxy "*" --max-time 90 -o /tmp/b.bin -w '%{http_code}' "$u" 2>&1)
  echo "  [$code] $(stat -c%s /tmp/b.bin 2>/dev/null)B  ${u:0:60}"
done

echo ""
echo "=== 4) 免费 pollen key 注册入口是否可达 ==="
curl -s --noproxy "*" --max-time 20 -o /dev/null -w "  enter.pollinations.ai: %{http_code}\n" \
  "https://enter.pollinations.ai/" 2>&1
