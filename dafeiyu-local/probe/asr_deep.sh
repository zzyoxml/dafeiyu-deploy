#!/bin/bash
set -u
echo "=== 1. AstrBot STT 默认配置全文 ==="
docker exec astrbot python3 -c "
import json, re
src = open('/AstrBot/astrbot/core/config/default.py', encoding='utf-8').read()
i = src.find('\"provider_stt_settings\"')
print(src[i:i+400])
" 2>&1 | head -25

echo ""
echo "=== 2. 当前生效配置里 STT 是什么 ==="
docker exec astrbot python3 -c "
import json
p='/AstrBot/data/cmd_config.json'
d=json.load(open(p, encoding='utf-8-sig'))
print('  provider_stt_settings:', json.dumps(d.get('provider_stt_settings'), ensure_ascii=False))
print('  provider_settings 里的 STT 相关:')
ps=d.get('provider_settings',{})
for k,v in ps.items():
    if 'stt' in k.lower() or 'speech' in k.lower() or 'whisper' in k.lower():
        print(f'    {k} = {v}')
" 2>&1 | tail -10

echo ""
echo "=== 3. STT provider 实现类在哪 ==="
docker exec astrbot sh -c "find /AstrBot/astrbot -type d -name '*stt*' 2>/dev/null" 2>&1 | head

echo ""
echo "=== 4. 谁调用 STT（找钩子）==="
docker exec astrbot sh -c "grep -rn 'get_stt_provider\|stt_provider\|provider_stt' /AstrBot/astrbot/core/ 2>/dev/null | head -10" 2>&1

echo ""
echo "=== 5. Record 转文字的关键逻辑 ==="
docker exec astrbot sh -c "grep -rn 'Record' /AstrBot/astrbot/core/pipeline/ 2>/dev/null | head -10" 2>&1

echo ""
echo "=== 6. app/napcat 语音文件路径 ==="
docker exec napcat sh -c "ls /app/.config/QQ/NapCat/temp/*.amr 2>/dev/null | head -3; ls /app/.config/QQ/NapCat/temp/ 2>/dev/null | head -5" 2>&1
