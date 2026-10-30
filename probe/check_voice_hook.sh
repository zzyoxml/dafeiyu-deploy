#!/bin/bash
set -u
echo "=== 1. dsh-voice 怎么在回复后发语音（参考实现）==="
docker exec astrbot sh -c "grep -n 'on_decorating_result\|on_llm_response\|get_result\|result_chain' /AstrBot/data/plugins/dsh-voice/main.py | head -15"

echo ""
echo "=== 2. 看具体钩子代码 ==="
docker exec astrbot sh -c "grep -n -A25 'on_llm_response' /AstrBot/data/plugins/dsh-voice/main.py | head -40"
