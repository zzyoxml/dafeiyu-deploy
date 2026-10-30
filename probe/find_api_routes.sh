#!/bin/bash
set -u
JWT=$(cat /tmp/astrbot_jwt 2>/dev/null)
echo "=== 1. 找 WebUI 真实 API 端点 ==="
docker exec astrbot sh -c "grep -rn 'api/plugin' /AstrBot/astrbot/dashboard/routes/*.py 2>/dev/null | head -12"

echo ""
echo "=== 2. 列出所有路由前缀 ==="
docker exec astrbot sh -c "grep -rn 'add_url_rule\|\.route\|add_route' /AstrBot/astrbot/dashboard/routes/plugin.py 2>/dev/null | head -10"
