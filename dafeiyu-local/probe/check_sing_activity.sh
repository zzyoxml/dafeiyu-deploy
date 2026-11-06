#!/bin/bash
set -u
echo "=== 1. dsh-sing 相关日志（全部）==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "\[sing\]" | tail -40

echo ""
echo "=== 2. 唱歌/搜歌/原唱/翻唱 命令触发记录 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "唱歌|搜歌|原唱|翻唱" | grep -viE "会唱歌的小鲸鱼|dsh-social|dsh-memory" | tail -25

echo ""
echo "=== 3. 最近的错误/异常 ==="
docker logs astrbot --tail 200 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "error|error:|失败|exception|traceback|未就绪|没发出去" | tail -15

echo ""
echo "=== 4. 音频目录里最新产物 ==="
ls -lht /opt/dafeiyu/data/astrbot/audio/ 2>/dev/null | head -8

echo ""
echo "=== 5. 工作目录残留（看是否卡在某一步）==="
ls -lht /opt/dafeiyu/data/astrbot/sing/work/ 2>/dev/null | head -8
