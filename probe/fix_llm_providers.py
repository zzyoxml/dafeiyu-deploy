"""修复 AstrBot 的 LLM provider：换掉全部失效模型

诊断结果（2026-10-29 实测网关 http://<HOST_GATEWAY>:18901/v1）：

  失效：
    openai/buddy/hy3               content=null（finish_reason=length，等于不出话）
    openai/buddy/deepseek-v4.1-flash  CodeBuddy 积分耗尽
    openai/buddy/hy3-x             CodeBuddy 积分耗尽
    openai/space-bunny-free        模型不存在（not found）
    openai/buddy/deepseek-v4-flash CodeBuddy 积分耗尽
    openai/zcode/GLM-5.3-Flash     zcode 额度用尽

  实测可用（能真实返回「你好」）：
    trae/deepseek-v4.1-flash
    trae/glm-5.3-flash
    trae/kimi-k2.5
    kilo-auto/free

做法：
  把 provider 列表替换成 4 个可用模型，
  默认图片描述 provider 也改到可用的（原先是 buddy/hy3）。
  保留 provider_source_id = "openai"（网关地址不变）。
"""

import json
import shutil
import sys
import time

P = "/AstrBot/data/cmd_config.json"
BAK = P + ".bak-llmfix-" + time.strftime("%Y%m%d-%H%M%S")

raw = open(P, encoding="utf-8-sig").read()
d = json.loads(raw)

GOOD = [
    ("openai/trae/deepseek-v4.1-flash", "trae/deepseek-v4.1-flash", ["text", "image", "tool_use"]),
    ("openai/trae/glm-5.3-flash", "trae/glm-5.3-flash", ["text", "image", "tool_use"]),
    ("openai/trae/kimi-k2.5", "trae/kimi-k2.5", ["text", "image", "tool_use"]),
    ("openai/kilo-auto/free", "kilo-auto/free", ["text", "tool_use"]),
]

new_provs = []
for pid, model, modal in GOOD:
    new_provs.append(
        {
            "id": pid,
            "enable": True,
            "provider_source_id": "openai",
            "model": model,
            "modalities": modal,
            "custom_extra_body": {},
            "max_context_tokens": 0,
        }
    )

old_ids = [p.get("id") for p in d.get("provider", [])]
d["provider"] = new_provs
print("[llm] 旧 provider:", old_ids)
print("[llm] 新 provider:", [p["id"] for p in new_provs])

# 图片描述 provider 也要可用（原先指向 buddy/hy3，已失效）
cfg = d.setdefault("provider_settings", {})
if cfg.get("default_image_caption_provider_id") not in {p["id"] for p in new_provs}:
    cfg["default_image_caption_provider_id"] = new_provs[0]["id"]
    print("[llm] 图片描述 provider ->", new_provs[0]["id"])

# provider_pool 保持 ['*']（所有启用项都会用），现在列表里全是可用模型
cfg["provider_pool"] = ["*"]

shutil.copy2(P, BAK)
# 原文件是带 BOM 的，写回时保留 BOM
with open(P, "w", encoding="utf-8-sig") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)

print("[write] 已写入，备份:", BAK)

# 校验
chk = json.loads(open(P, encoding="utf-8-sig").read())
print("[check] provider 数量 =", len(chk["provider"]))
print("[check] image caption =", chk["provider_settings"]["default_image_caption_provider_id"])
