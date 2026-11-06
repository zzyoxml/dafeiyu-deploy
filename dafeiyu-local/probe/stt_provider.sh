#!/bin/bash
set -u
echo "=== 1. sensevoice 自托管 provider 需要什么 ==="
docker exec astrbot sh -c "sed -n '1,60p' /AstrBot/astrbot/core/provider/sources/sensevoice_selfhosted_source.py" 2>&1

echo ""
echo "=== 2. whisper 自托管 provider 配置（对比）==="
docker exec astrbot sh -c "sed -n '1,40p' /AstrBot/astrbot/core/provider/sources/whisper_selfhosted_source.py" 2>&1
