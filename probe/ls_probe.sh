#!/bin/bash
set -u
echo "=== WSL probe 目录里现有的 stt 相关文件 ==="
ls -la /opt/dafeiyu/probe/ 2>/dev/null | grep -iE "stt|asr" | sed 's/^/  /' || echo "  无"
echo ""
echo "=== probe 目录总文件数 ==="
ls /opt/dafeiyu/probe/ 2>/dev/null | wc -l | xargs -I{} echo "  {} 个文件"
