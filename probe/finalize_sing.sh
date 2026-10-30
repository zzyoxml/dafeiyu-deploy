#!/bin/bash
set -u
echo "=== 1. 清理测试残留 ==="
rm -rf /AstrBot/data/sing/work/e2e-* 2>/dev/null
rm -f /AstrBot/data/audio/e2e-test-*.mp3 2>/dev/null
echo "  已清理"

echo ""
echo "=== 2. 备份插件到 Windows 侧 ==="
cp /opt/dafeiyu/data/astrbot/plugins/dsh-sing/main.py \
   <PROBE_DIR>/dsh-sing/main.py.deployed 2>/dev/null
echo "  已备份"

echo ""
echo "=== 3. 最终环境清单 ==="
echo "  [Python venv]"
docker exec astrbot /AstrBot/data/sing/venv/bin/python -c "import torch,demucs,torchaudio; print('    torch', torch.__version__); print('    torchaudio', torchaudio.__version__); print('    demucs OK')" 2>&1 | sed 's/^/  /'
echo ""
echo "  [模型]"
docker exec astrbot sh -c "ls -lh /AstrBot/data/sing/model/liuying.pth /AstrBot/data/sing/rvc_cli/rvc/models/predictors/rmvpe.pt /AstrBot/data/sing/rvc/models/embedders/contentvec/pytorch_model.bin" 2>&1 | awk '{print "    "$5" "$9}'
echo ""
echo "  [磁盘占用]"
du -sh /opt/dafeiyu/data/astrbot/sing 2>/dev/null | sed 's/^/    sing 总大小: /'

echo ""
echo "=== 4. 插件加载确认 ==="
docker logs astrbot 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -i "dsh-sing" | grep -i "Plugin dsh-sing" | tail -2

echo ""
echo "=== 5. QQ 是否在线 ==="
docker logs astrbot --tail 30 2>&1 | sed "s/\x1b\[[0-9;]*m//g" | grep -iE "isLogin|在线|连接成功|ready" | tail -3
