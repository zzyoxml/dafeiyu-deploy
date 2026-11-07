#!/bin/bash
echo "=== compose env config ==="
grep -nE "env_file|environment|robot.env" /opt/dafeiyu/docker-compose.yml | head -20
echo "=== DSH_IMG env inside astrbot PID 1 ==="
docker exec astrbot sh -c "tr '\000' '\n' < /proc/1/environ | grep DSH_IMG" | head -25
echo "=== does plugin see AUTO_CONCEPT? plugin log ==="
docker logs astrbot --since 2m 2>&1 | grep "\[imagegen\] 已加载" | tail -2
