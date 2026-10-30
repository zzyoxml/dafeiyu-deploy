#!/bin/bash
set -u
echo "=== 1. dsh-voice 的 on_llm_response 签名 ==="
docker exec astrbot sh -c "sed -n '1220,1245p' /AstrBot/data/plugins/dsh-voice/main.py"

echo ""
echo "=== 2. 框架里 on_llm_response 的调用方式 ==="
docker exec astrbot sh -c "grep -rn -A6 'on_llm_response' /AstrBot/astrbot/core/pipeline/process_stage/*.py 2>/dev/null | head -20"
docker exec astrbot sh -c "grep -rn 'OnLLMResponse\|llm_response' /AstrBot/astrbot/core/star/register/star_handler.py | head -8"
