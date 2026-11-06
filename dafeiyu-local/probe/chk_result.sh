#!/bin/bash
set -u
P=/opt/dafeiyu/data/astrbot/plugins

echo "=== selfguard 里的 result 操作 ==="
grep -n "stop_event\|clear_result\|set_result" "$P/dsh-selfguard/main.py"

echo ""
echo "=== reply-guard 里的 result 操作（看不发言怎么写）==="
grep -n "stop_event\|clear_result\|set_result" "$P/dsh-reply-guard/main.py"

echo ""
echo "=== 其他插件里 stop_event 的用法 ==="
grep -rn "event.stop_event()" "$P" --include=*.py | head -8
