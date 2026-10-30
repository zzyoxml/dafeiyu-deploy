#!/bin/bash
set -u
ENVFILE=/opt/dafeiyu/robot.env
BAK="${ENVFILE}.bak-$(date +%Y%m%d-%H%M%S)"
cp "$ENVFILE" "$BAK"
echo "  已备份 → $BAK"

# 先删掉旧的本段配置（幂等）
python3 - <<'PYEOF'
import re, pathlib
p = pathlib.Path("/opt/dafeiyu/robot.env")
txt = p.read_text(encoding="utf-8")
# 删掉我们之前加过的段
for marker in ("# ===== 唱歌技能", "# ===== 语音流萤", "# ===== 回复节流"):
    idx = txt.find(marker)
    if idx >= 0:
        # 找到下一个 "# =====" 或文件尾
        nxt = txt.find("\n# =====", idx + 1)
        txt = txt[:idx] + (txt[nxt+1:] if nxt >= 0 else "")
new_block = """
# ===== 唱歌技能（2026-10-30）=====
# 成品缓存：同一首歌再点直接复用，不重跑 demucs/RVC。LRU 上限 100 首。
DSH_SING_CACHE_MAX=100
# 群友权限：owner / original / ai。ai = 群友可用 /原唱 + /唱歌
DSH_SING_GROUP_ACCESS=ai
# 群友单次片段上限（秒）与冷却
DSH_SING_MAX_SECONDS_GROUP=30
DSH_SING_COOLDOWN_USER=120
DSH_SING_COOLDOWN_GROUP=30
DSH_SING_QUEUE_WAIT=180
# 主人 QQ
DSH_SING_OWNER=<主人QQ>
DSH_SELF_ID=<BOT_QQ>

# ===== 语音流萤音色（2026-10-30）=====
# 普通回复按概率自动用流萤音色出声
DSH_VOICE_LY_RATE=0.20
# 只念 4~40 字：太短没意思，太长变声慢且群里没人愿意听
DSH_VOICE_LY_MAX_CHARS=40
# 全局冷却与小时配额，避免连发
DSH_VOICE_LY_COOLDOWN=45
DSH_VOICE_LY_HOURLY=8
# 单次变声超时（CPU 4 核，40 字约 40~60s）
DSH_VOICE_LY_TIMEOUT=300
# Edge 底音 + 参数（再过 RVC 变流萤）
DSH_VOICE_LY_EDGE_VOICE=zh-CN-XiaoxiaoNeural
DSH_VOICE_LY_EDGE_RATE=-5%
DSH_VOICE_LY_EDGE_PITCH=+2Hz

# ===== 回复节流（2026-10-30）=====
# 普通文字一分钟最多 10 条（滑动窗口）
DSH_GUARD_RATE_WINDOW=60
DSH_GUARD_RATE_MAX=10
# 主人豁免限流（但陈旧拦截不豁免）
DSH_GUARD_OWNER_BYPASS=1
# 群里积压超过 10 句且未点名/@ 时不接话
DSH_GUARD_STALE=1
DSH_GUARD_STALE_LAG=10
"""
p.write_text(txt.rstrip() + "\n" + new_block, encoding="utf-8")
print("  已写入配置")
PYEOF

echo ""
echo "=== 校验写入结果 ==="
grep -c "^DSH_" "$ENVFILE" | xargs -I{} echo "  共 {} 个 DSH_ 变量"
echo ""
echo "  新增段:"
grep -E "^DSH_(SING_CACHE|VOICE_LY|GUARD)" "$ENVFILE" | sed 's/^/    /'
