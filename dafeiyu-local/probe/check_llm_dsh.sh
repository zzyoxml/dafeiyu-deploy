#!/bin/bash
# 等待 astrbot 健康并检查 LLM 配置是否生效
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  s=$(docker inspect -f '{{.State.Health.Status}}' astrbot)
  if [ "$s" = "healthy" ]; then break; fi
  sleep 5
done
echo "status=$s"
echo "=== 最近日志中的 provider/错误 ==="
docker logs astrbot --since 3m 2>&1 | grep -iE 'provider|llm|401|403|unauthorized|error' | tail -15
