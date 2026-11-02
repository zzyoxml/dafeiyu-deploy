"""启用 AstrBot 的 SenseVoice STT provider。"""
import json

P = "/AstrBot/data/cmd_config.json"
d = json.load(open(P, encoding="utf-8-sig"))

stt_id = "sensevoice/SenseVoiceSmall"
providers = [p for p in d.get("provider", []) if p.get("id") != stt_id]
providers.append({
    "id": stt_id,
    "enable": True,
    "provider_source_id": "sensevoice_stt_selfhost",
    "type": "sensevoice_stt_selfhost",
    "stt_model": "/AstrBot/data/stt-models/models/iic--SenseVoiceSmall-onnx/snapshots/master",
    "is_emotion": False,
})
d["provider"] = providers
d["provider_stt_settings"] = {"enable": True, "provider_id": stt_id}

json.dump(d, open(P, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"  provider 数量: {len(providers)}")
print(f"  stt_settings: {d['provider_stt_settings']}")
print("  ✅ 已写入")

# 回读校验
d2 = json.load(open(P, encoding="utf-8-sig"))
print(f"  回读 stt: {d2.get('provider_stt_settings')}")
for p in d2.get("provider", []):
    if "sensevoice" in str(p.get("id", "")):
        print(f"  回读 STT provider: id={p['id']} enable={p['enable']}")
