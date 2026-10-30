#!/bin/bash
set -u
echo "=== 1. 重建前那次点歌到底走到哪一步 ==="
W=/opt/dafeiyu/data/astrbot/sing/work/ai-20261030122912
echo "  工作目录: $W（创建于 12:29:12）"
ls -la "$W" 2>/dev/null
echo ""
echo "  clip.wav 时长:"
docker exec astrbot ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 "$W/clip.wav" 2>/dev/null | sed 's/^/    /'
echo ""
echo "  结论：download + 截取 已完成，卡在 demucs（无 demucs 输出目录）"

echo ""
echo "=== 2. 容器重建时间点对照 ==="
echo "  点歌开始 : 12:29:12（上一代容器）"
echo "  我重建容器: 12:30:21（--force-recreate）"
echo "  → 这次点歌是被我打断的，不是插件问题"

echo ""
echo "=== 3. 清理孤儿工作目录 ==="
rm -rf /opt/dafeiyu/data/astrbot/sing/work/ai-20261030122912
rm -rf /opt/dafeiyu/data/astrbot/sing/work/e2e-20261030122026
rm -f /opt/dafeiyu/data/astrbot/audio/e2e-test-*.mp3
echo "  已清理"

echo ""
echo "=== 4. 确认当前可用性（插件已加载 + 权限已开）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "Plugin dsh-sing" | tail -1
docker exec astrbot sh -c "env | grep -E 'DSH_SING_GROUP_ACCESS|DSH_SING_MAX'"
