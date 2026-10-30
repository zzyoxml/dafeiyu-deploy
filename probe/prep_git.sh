#!/bin/bash
set -u
echo "=== 1. 检查插件目录里的可疑大文件 / 二进制 ==="
find /opt/dafeiyu/data/astrbot/plugins -type f \( -size +5M -o -name "*.mp3" -o -name "*.wav" -o -name "*.pth" -o -name "*.bin" \) 2>/dev/null | head -20 | while read f; do
  echo "  $(du -h "$f" | cut -f1)  ${f#/opt/dafeiyu/data/astrbot/plugins/}"
done

echo ""
echo "=== 2. 插件目录里的数据库/状态文件 ==="
find /opt/dafeiyu/data/astrbot/plugins -type f \( -name "*.db" -o -name "*.jsonl" -o -name "*.log" \) 2>/dev/null | head -20 | while read f; do
  echo "  $(du -h "$f" | cut -f1)  ${f#/opt/dafeiyu/data/astrbot/plugins/}"
done

echo ""
echo "=== 3. 有 __pycache__ 吗 ==="
find /opt/dafeiyu/data/astrbot/plugins -type d -name "__pycache__" 2>/dev/null | wc -l

echo ""
echo "=== 4. robot.env 里的密钥行（需要脱敏）==="
grep -E "KEY|TOKEN|SECRET|PASSWORD" /opt/dafeiyu/robot.env 2>/dev/null | sed 's/([A-Za-z0-9_-]*[A-Za-z0-9])/(***)/' | cut -c1-60

echo ""
echo "=== 5. 插件源码总大小（不含 pycache）==="
find /opt/dafeiyu/data/astrbot/plugins -type f -name "*.py" 2>/dev/null | xargs du -ch 2>/dev/null | tail -1
find /opt/dafeiyu/data/astrbot/plugins -type f -name "*.yaml" 2>/dev/null | wc -l | xargs -I{} echo "  metadata.yaml: {} 个"

echo ""
echo "=== 6. 配置文件清单（顶层）==="
for f in /opt/dafeiyu/docker-compose.yml /opt/dafeiyu/onebot11.json /opt/dafeiyu/_setup.sh; do
  [ -f "$f" ] && echo "  $(du -h "$f" | cut -f1)  $(basename $f)"
done
