#!/bin/bash
set -u
echo "=== 1. 备份 cmd_config.json ==="
docker exec astrbot sh -c "cp /AstrBot/data/cmd_config.json /AstrBot/data/cmd_config.json.bak-stt-$(date +%H%M%S)"
echo "  已备份"

echo ""
echo "=== 2. 写入 STT provider + 启用 ==="
docker exec astrbot python3 - <<'PYEOF'
import json, copy
P = '/AstrBot/data/cmd_config.json'
d = json.load(open(P, encoding='utf-8-sig'))

# 1) 加一个 sensevoice STT provider
stt_id = 'sensevoice/SenseVoiceSmall'
providers = d.get('provider', [])
# 去重
providers = [p for p in providers if p.get('id') != stt_id]
providers.append({
    "id": stt_id,
    "enable": True,
    "provider_source_id": "sensevoice_stt_selfhost",
    "type": "sensevoice_stt_selfhost",
    "stt_model": "/AstrBot/data/stt-models/models/iic--SenseVoiceSmall-onnx/snapshots/master",
    "is_emotion": False,
})
d['provider'] = providers
print(f"  provider 数量: {len(providers)}")

# 2) 启用 STT
d['provider_stt_settings'] = {"enable": True, "provider_id": stt_id}
print(f"  provider_stt_settings: {d['provider_stt_settings']}")

json.dump(d, open(P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print("  ✅ 已写入")
PYEOF

echo ""
echo "=== 3. 验证写入结果 ==="
docker exec astrbot python3 -c "
import json
d=json.load(open('/AstrBot/data/cmd_config.json', encoding='utf-8-sig'))
print('  stt_settings:', d.get('provider_stt_settings'))
for p in d.get('provider',[]):
    if 'sensevoice' in str(p.get('id','')):
        print('  STT provider:')
        for k,v in p.items(): print(f'    {k} = {v}')
"
