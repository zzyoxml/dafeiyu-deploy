#!/bash
set -u
echo "=== 1. 语音发送失败的完整错误 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -B10 -A10 "这次声音没送出去" | tail -30

echo ""
echo "=== 2. dsh-voice 的 [voice] 日志 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "\[voice\]" | tail -20

echo ""
echo "=== 3. Record 发送相关错误 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "record|silk|retcode|1200|语音" | tail -15
