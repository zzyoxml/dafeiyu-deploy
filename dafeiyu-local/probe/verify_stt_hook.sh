#!/bin/bash
set -u
echo "=== 1. stt-clean 的钩子是否注册 ==="
docker logs astrbot 2>&1 | grep -iE "clean_stt|handler.*stt-clean|Added.*stt" | tail -5
echo ""
echo "  官方注册日志模式:"
docker logs astrbot 2>&1 | grep -iE "Registered|handler|on_llm_request" | grep -i "stt" | tail -3 || echo "  （没有）"

echo ""
echo "=== 2. 验证钩子确实被调用（造一条带标签的消息）==="
docker exec astrbot python3 -c "
import asyncio, sys
sys.path.insert(0,'/AstrBot')
# 直接测插件方法本身，确认逻辑可用
import importlib.util
spec = importlib.util.spec_from_file_location('sc', '/AstrBot/data/plugins/dsh-stt-clean/main.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class FakeObj: message_str = ''; message = []
class FakeEvent:
    message_str = '<|Singing|>不敢轻皮黄颜红'
    message_obj = FakeObj()
    message_obj.message_str = '<|Singing|>不敢轻皮黄颜红'

e = FakeEvent()
inst = m.SttCleanPlugin.__new__(m.SttCleanPlugin)
asyncio.run(inst.clean_stt(e, None))
print('  输入: <|Singing|>不敢轻皮黄颜红')
print('  输出:', e.message_str)
" 2>&1 | tail -8

echo ""
echo "=== 3. 最近的 stt-clean 日志（如果有真实语音进来）==="
docker logs astrbot 2>&1 | grep -i "stt-clean" | tail -5
</script>
</invoke>
