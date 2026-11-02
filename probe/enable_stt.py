#!/bin/bash
# 把 SenseVoice provider 写进 cmd_config.json 并启用 STT
#
# 为什么用 python 而不是 docker exec + heredoc：
#   heredoc 在 docker exec 里 stdin 传不进去，内容会被吞掉，改完配置没生效。
#   正确做法是写成 .py 文件，docker cp 进去再执行。
#
# 回读校验必做：这一步曾经在「已写入」的假象下其实什么都没改。
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

