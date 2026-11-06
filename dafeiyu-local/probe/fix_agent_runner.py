"""修复 agent_runner 与 subagent_orchestrator 的模型引用

上一轮只改了 provider 列表，但真正决定用哪个模型的是：
  agent_runner.config.model.provider_id          -> 还是 openai/buddy/hy3（已失效）
  agent_runner.config.model.fallback_provider_ids -> 全是失效模型
  subagent_orchestrator.agents[*].provider_id     -> openai/zcode/GLM-5.3-Flash（额度用尽）

全部替换为实测可用的 4 个：
  openai/trae/deepseek-v4.1-flash  （主力）
  openai/trae/glm-5.3-flash
  openai/trae/kimi-k2.5
  openai/kilo-auto/free
"""

import json
import shutil
import time

P = "/AstrBot/data/cmd_config.json"
GOOD = [
    "openai/trae/deepseek-v4.1-flash",
    "openai/trae/glm-5.3-flash",
    "openai/trae/kimi-k2.5",
    "openai/kilo-auto/free",
]

d = json.loads(open(P, encoding="utf-8-sig").read())
bak = P + ".bak-agent-" + time.strftime("%Y%m%d-%H%M%S")
shutil.copy2(P, bak)
print("[bak]", bak)

# ── 1. agent_runner ─────────────────────────────────────────
ar = d.setdefault("agent_runner", {})
cfg = ar.setdefault("config", {})
model = cfg.setdefault("model", {})

old_pid = model.get("provider_id")
model["provider_id"] = GOOD[0]
print("[agent] provider_id: %s -> %s" % (old_pid, GOOD[0]))

old_fb = model.get("fallback_provider_ids", [])
model["fallback_provider_ids"] = GOOD[1:]
print("[agent] fallback: %d 个 -> %d 个（%s）" % (len(old_fb), len(GOOD[1:]), GOOD[1:]))

# ── 2. subagent_orchestrator ────────────────────────────────
so = d.get("subagent_orchestrator", {})
agents = so.get("agents", []) if isinstance(so, dict) else []
valid = set(GOOD)
fixed = 0
for a in agents:
    pid = a.get("provider_id")
    if pid not in valid:
        a["provider_id"] = GOOD[0]
        fixed += 1
        print("[subagent] %s: %s -> %s" % (a.get("name"), pid, GOOD[0]))
print("[subagent] 修正 %d 个子代理" % fixed)

# ── 3. 兜底：全局扫一遍还有没有旧 ID ───────────────────────────
raw = json.dumps(d, ensure_ascii=False)
OLD_IDS = [
    "openai/buddy/hy3",
    "openai/buddy/hy3-x",
    "openai/buddy/deepseek-v4.1-flash",
    "openai/buddy/deepseek-v4-flash",
    "openai/buddy/deepseek-v4-pro",
    "openai/buddy/glm-5.3-flash",
    "openai/space-bunny-free",
    "openai/beam-free",
    "openai/zcode/GLM-5.3-Flash",
    "openai/kilo-auto/free",
    "openai/longcat-2.5-preview-free",
    "openai/jev-1.13-free",
    "openai/cohere/north-mini-code:free",
    "openai/deepseek-v4.1-flash-free",
    "openai/glm-5.3-flash-free",
    "openai/xingchen-agi/xing4.0-29b-a4b:free",
]
# 注意：这些 ID 现在是字符串，替换时要小心不要把新 ID 也换掉。
# 用临时占位符避免连锁替换。
remaining = [oid for oid in OLD_IDS if oid in raw and oid not in GOOD]
print("[scan] 文本中仍残留旧 ID:", remaining)

if remaining:
    for i, oid in enumerate(remaining):
        raw = raw.replace(oid, "__TMP_%d__" % i)
    for i, oid in enumerate(remaining):
        # 全部指向主力模型
        raw = raw.replace("__TMP_%d__" % i, GOOD[0])
    d = json.loads(raw)
    print("[scan] 已全部改指", GOOD[0])

with open(P, "w", encoding="utf-8-sig") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)

# ── 校验 ────────────────────────────────────────────────────
chk = json.loads(open(P, encoding="utf-8-sig").read())
print()
print("[check] agent_runner.provider_id =", chk["agent_runner"]["config"]["model"]["provider_id"])
print("[check] fallback =", chk["agent_runner"]["config"]["model"]["fallback_provider_ids"])
print("[check] provider 列表 =", [p["id"] for p in chk["provider"]])
still = [oid for oid in OLD_IDS if oid in json.dumps(chk, ensure_ascii=False) and oid not in GOOD]
print("[check] 残留旧 ID =", still if still else "无 ✅")
