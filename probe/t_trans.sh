#!/usr/bin/env bash
# 用真实 provider 验证翻译效果（绕开 Context，直接调 provider）
set -u
cat > /tmp/t4.py <<'PYEOF'
import asyncio, json, aiohttp

K = "<你的OFM_KEY>"
B = "http://<HOST_GATEWAY>:18901/v1"

SYS = ("把下面这句中文画图描述翻译成英文提示词。"
       "只输出英文，不要解释、不要引号、不要加任何风格词。"
       "保留主体、数量、颜色、动作、场景。")

async def tr(zh):
    async with aiohttp.ClientSession() as s:
        async with s.post(f"{B}/chat/completions",
            headers={"Authorization": f"Bearer {K}", "Content-Type": "application/json"},
            json={"model": "buddy/hy3",
                  "messages": [{"role": "user", "content": f"{SYS}\n中文：{zh}\n英文："}],
                  "max_tokens": 100, "temperature": 0.2},
            timeout=aiohttp.ClientTimeout(total=30)) as r:
            d = await r.json()
            return (d["choices"][0]["message"].get("content") or "").strip()

async def go():
    for zh in ["一只圆滚滚的蓝白色胖鲸鱼",
               "画个在吃面的程序员",
               "一只戴墨镜的猫在晒太阳",
               "大肥鱼在群里发表情包"]:
        en = await tr(zh)
        print(f"  {zh}")
        print(f"    -> {en}")
        print()

asyncio.run(go())
PYEOF
docker cp /tmp/t4.py astrbot:/tmp/t4.py
docker exec astrbot python3 /tmp/t4.py 2>&1
