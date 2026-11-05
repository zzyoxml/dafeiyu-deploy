#!/usr/bin/env bash
# 一键停止 QQ 机器人：guard 守护 + 两个容器全停
# 用法：双击 D:\xml\dafeiyu\stop.bat

echo "===[1/3] 停 WSL 内 guard 进程 ==="
pkill -f "guard.sh" 2>/dev/null && echo "  guard 已停止" || echo "  guard 未在运行"
rm -f /opt/dafeiyu/logs/guard.lock 2>/dev/null

echo "===[2/3] 停容器（astrbot + napcat）==="
docker stop astrbot napcat 2>/dev/null && echo "  容器已停止" || echo "  容器本就未运行"

echo "===[3/3] 状态确认 ==="
RUN=$(docker ps --format '{{.Names}}' | grep -cE 'astrbot|napcat')
if [ "$RUN" = "0" ]; then
  echo "  全部已停止，机器人完全离线"
else
  echo "  警告：仍有 $RUN 个容器在运行"
  docker ps --format '  {{.Names}} | {{.Status}}' | grep -E 'astrbot|napcat'
fi
