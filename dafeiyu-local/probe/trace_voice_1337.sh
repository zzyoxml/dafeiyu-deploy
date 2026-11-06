#!/bin/bash
set -u
echo "=== 1. 13:37:23 那条消息的完整处理链 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" \
  | awk '/13:37:2[3-9]/,/13:38:3/' \
  | grep -vE "awareness|dsh-proactive|dsh-decide|dsh-persona|dsh-mind|dsh-scene|dsh-style|dsh-ctxclean|dsh-memory|dsh-desire|dsh-interest|dsh-social|dsh-agency|dsh-emotion|dsh-selfaware|dsh-explore|dsh-followup|dsh-imagegen|dsh-quoteref|dsh-clarify" \
  | head -25

echo ""
echo "=== 2. dsh-voice 这次动作 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:37/,/13:39/' | grep -E "\[voice\]" | tail -12

echo ""
echo "=== 3. 语音产物（TMP_DIR）==="
docker exec astrbot sh -c "ls -lht /AstrBot/data/audio/ 2>/dev/null | head -5"
docker exec astrbot sh -c "ls -lht /tmp/tts_*.mp3 2>/dev/null | head -3"

echo ""
echo "=== 4. 是否有 Record 发出 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | awk '/13:37:3/,/13:39/' | grep -iE "record|ComponentType" | tail -5
