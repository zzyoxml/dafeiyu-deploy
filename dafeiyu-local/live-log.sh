#!/usr/bin/env bash
# 实时对话日志：每条消息的 收到 → 思考 → 回复 全过程
# 用法：双击 D:\xml\dafeiyu\logs.bat，关窗口或 Ctrl+C 退出
# [A] = AstrBot（收消息/LLM/插件动作/报错）  [Q] = QQ(NapCat)（消息进出/登录态）
set -u

# astrbot 关心的行：消息管道、LLM、常用插件、报错
A='接收|发送|\[steal\]|\[imagegen\]|\[decide\]|\[awake\]|\[memory\]|\[imgctx\]|LLM|provider|error|Error|ERROR|WARN|表情|画|语音|\[human\]|\[style\]|\[scene\]|\[effect\]|\[awareness\]|\[mute\]|\[guard\]|\[persona|Prepare to send'
# napcat 关心的行：消息进出、登录态、连接
N='接收|发送|Login|在线|下线|error|WebSocket|二维码'
# 启动噪音：插件加载横幅（只在重启后几分钟出现，平时没用）
NOISE='Plugin dsh-|Loading plugin|Added llm tool|star_manager|func_tool_manager|deprecation|provider.manager|Loading model|Selected openai'

cleanup() { kill $(jobs -p) 2>/dev/null; exit 0; }
trap cleanup INT TERM

# 先回放最近 10 分钟，再实时跟随
docker logs --since 10m astrbot 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -aE "$A" \
  | grep -avE "$NOISE" \
  | sed 's/^/[A] /'

docker logs --since 10m napcat 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -aE "$N" \
  | sed 's/^/[Q] /'

echo "--------------------------------------------------------------"
echo "  以上是最近 10 分钟回放，下面开始实时显示（Ctrl+C 退出）"
echo "--------------------------------------------------------------"

docker logs -f astrbot 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep --line-buffered -aE "$A" \
  | grep --line-buffered -avE "$NOISE" \
  | sed -u 's/^/[A] /' &

docker logs -f napcat 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep --line-buffered -aE "$N" \
  | sed -u 's/^/[Q] /' &

wait
