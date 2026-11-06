#!/bin/bash
set -u
echo "=== 1. data 下各目录体积 ==="
du -sh /opt/dafeiyu/data/* 2>/dev/null | sort -h

echo ""
echo "=== 2. data/astrbot 下各目录 ==="
du -sh /opt/dafeiyu/data/astrbot/* 2>/dev/null | sort -h | tail -15

echo ""
echo "=== 3. 超过 50MB 的单个文件 ==="
find /opt/dafeiyu -type f -size +50M 2>/dev/null | head -30 | while read f; do
  echo "  $(du -h "$f" | cut -f1)  $f"
done

echo ""
echo "=== 4. plugins 体积 ==="
du -sh /opt/dafeiyu/data/astrbot/plugins 2>/dev/null
echo "  插件数: $(ls -d /opt/dafeiyu/data/astrbot/plugins/dsh-* 2>/dev/null | wc -l)"

echo ""
echo "=== 5. repo / patches 是什么 ==="
ls /opt/dafeiyu/repo/ 2>/dev/null | head -6
echo "  ---"
ls -R /opt/dafeiyu/patches/ 2>/dev/null | head -12

echo ""
echo "=== 6. 敏感文件检查 ==="
ls -la /opt/dafeiyu/robot.env | awk '{print "  robot.env", $1, $5, "bytes"}'
echo "  含密钥的行数:"
grep -cE "KEY|TOKEN|SECRET|PASSWORD" /opt/dafeiyu/robot.env 2>/dev/null
