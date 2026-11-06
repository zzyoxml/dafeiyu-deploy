#!/bin/bash
set -u
echo "=== 1. EventMessageType 有哪些值 ==="
cat > /tmp/chk_api.py <<'PYEOF'
from astrbot.api.event import filter
print("  EventMessageType:", [n for n in dir(filter.EventMessageType) if not n.startswith("_")])
PYEOF
docker cp /tmp/chk_api.py astrbot:/tmp/chk_api.py
docker exec astrbot python3 /tmp/chk_api.py 2>&1

echo ""
echo "=== 2. event 有没有 stop_event / get_extra ==="
docker exec astrbot sh -c "grep -n 'def stop_event\|def get_extra\|def set_extra\|_force_stopped' /AstrBot/astrbot/core/platform/astr_message_event.py | head -10"

echo ""
echo "=== 3. on_llm_request / on_waiting_llm_request 签名 ==="
docker exec astrbot sh -c "grep -n -A12 'def register_on_llm_request\|def register_on_waiting_llm_request' /AstrBot/astrbot/core/star/register/star_handler.py | head -35"

echo ""
echo "=== 4. 现有插件里 on_llm_request 的实际签名 ==="
docker exec astrbot sh -c "grep -rn -A3 '@filter.on_llm_request' /AstrBot/data/plugins/dsh-ctxclean/main.py /AstrBot/data/plugins/dsh-memory/main.py 2>/dev/null | head -12"
