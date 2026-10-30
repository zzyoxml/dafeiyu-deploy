#!/bash
set -u
echo "=== 1. 查 PyPI 上 edge-tts 可用版本 ==="
docker exec astrbot sh -c "/AstrBot/data/sing/venv/bin/python -m pip index versions edge-tts 2>&1 | head -5" || \
docker exec astrbot sh -c "pip index versions edge-tts 2>&1 | head -5"

echo ""
echo "=== 2. 升级到最新版 ==="
docker exec astrbot sh -c "pip install --index-url https://pypi.tuna.tsinghua.edu.cn/simple -U edge-tts 2>&1 | tail -5"

echo ""
echo "=== 3. 升级后版本 ==="
docker exec astrbot sh -c "python3 -c 'import edge_tts; print(edge_tts.__version__)'"

echo ""
echo "=== 4. 再测 403 ==="
docker exec astrbot python3 /tmp/test_edge.py 2>&1 | tail -4
