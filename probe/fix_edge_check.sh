#!/bin/bash
set -u
echo "=== 1. venv 里有 edge_tts 吗 ==="
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "import edge_tts; print('有', edge_tts.__version__)" 2>&1 | tail -2

echo ""
echo "=== 2. 主环境 edge_tts 版本 ==="
docker exec astrbot python3 -c "import edge_tts; print('主环境', edge_tts.__version__)" 2>&1 | tail -2

echo ""
echo "=== 3. 装到 venv 里（RVC 链在 venv 内跑，但 Edge 可以在主环境调）==="
echo "  方案：venv 里也装一份，保持依赖自洽"
docker exec astrbot /AstrBot/data/sing/venv/bin/python -m pip install \
  --index-url https://pypi.tuna.tsinghua.edu.cn/simple -q edge-tts 2>&1 | tail -3
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "import edge_tts; print('  venv 现在有', edge_tts.__version__)" 2>&1 | tail -2

echo ""
echo "=== 4. 修复检测逻辑（改为在主环境检测，因为插件跑在主环境）==="
echo "  插件 itself 在 AstrBot 主环境运行，import edge_tts 就是主环境的那份"
