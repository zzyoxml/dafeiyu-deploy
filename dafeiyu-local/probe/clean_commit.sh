#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 判断哪些是临时探路脚本（原样剔除）==="
TEMP="asr_deep.sh asr_survey.sh stt_detail.sh stt_env.sh stt_load.sh stt_provider.sh stt_tags.sh ls_probe.sh prep_commit.sh check_commits.sh commit_stt.sh commit_stt_scripts.sh fix_stt_clean_ver.sh"
for f in $TEMP; do
  if git ls-files "probe/$f" | grep -q .; then
    echo "  剔除: $f"
    git rm --cached -q "probe/$f" 2>/dev/null
    rm -f "probe/$f"
  fi
done

echo ""
echo "=== 2. 保留的（有长期价值）==="
git ls-files probe/ | grep -iE "stt|asr" | sed 's/^/  /'

echo ""
echo "=== 3. 给保留的脚本加说明头 ==="
python3 - <<'PYEOF'
from pathlib import Path

HEADERS = {
"install_stt.sh": """#!/bin/bash
# 安装 SenseVoice STT（本地 ONNX 推理，无需 API key）
#
# 踩过的坑（按顺序）：
#  1. iic/SenseVoiceSmall 是 PyTorch 版（892MB model.pt），funasr_onnx 只吃
#     model_quant.onnx，所以必须下 iic/SenseVoiceSmall-onnx
#  2. ONNX 那个仓库缺 chn_jpn_yue_eng_ko_spectok.bpe.model（377KB），
#     要单独从 iic/SenseVoiceSmall 补，否则加载报 RuntimeError NOT_FOUND
#  3. funasr_onnx 必须装进 **AstrBot 主环境**——provider 在容器主进程加载，
#     只装 sing/venv 会报 ModuleNotFoundError: No module named 'funasr_onnx'
#  4. is_emotion 必须 false，否则会把「(当前的情绪：HAPPY)」写进文本
#
# 模型最终 231MB，装在 /AstrBot/data/stt-models（挂载卷，容器重建不丢）
""",
"enable_stt.py": """#!/bin/bash
# 把 SenseVoice provider 写进 cmd_config.json 并启用 STT
#
# 为什么用 python 而不是 docker exec + heredoc：
#   heredoc 在 docker exec 里 stdin 传不进去，内容会被吞掉，改完配置没生效。
#   正确做法是写成 .py 文件，docker cp 进去再执行。
#
# 回读校验必做：这一步曾经在「已写入」的假象下其实什么都没改。
""",
"test_stt_direct.py": """#!/bin/bash
# 直连 SenseVoice provider 验证端到端（含 MediaResolver 转码链路）
#
# 为什么不能 from astrbot.core.provider.manager import ProviderManager：
#   会触发循环导入（manager → persona_mgr → api → star → kb_mgr → manager），
#   报 "cannot import name 'ProviderManager' from partially initialized module"。
#   所以只导 sources.sensevoice_selfhosted_source 里的类，手动实例化。
#
# 用途：改完环境/模型后跑这个，能一次性看清「加载耗时 / 识别文本 / 单句耗时」。
""",
"test_stt_acc.py": """#!/bin/bash
# STT 准确度回归：8 句已知文本（Edge TTS 合成）→ 识别 → 逐字比对
#
# 设计要点：
#  - 用 Edge TTS 现造音频，文本已知，才能算「完全一致」的比例
#  - 比对前归一化标点，因为 SenseVoice 会自己加标点/emoji
#  - 实测基线：5/8 完全一致，其余是标点或同音字差异（小鲸鱼→小金鱼）
""",
"test_stt_clean2.py": """#!/bin/bash
# dsh-stt-clean 的离线逻辑回归（9 个场景）
#
# 为什么单独有这个测试：
#   插件第一版写 if 'Singing' in tags，但 tags 存的是完整标签 '<|Singing|>'，
#   集合精确匹配永远 False，前缀从没加上过——肉眼看日志发现不了，必须用断言。
#
# 场景覆盖：唱歌带词 / BGM 带词 / 纯 Singing / 纯 BGM / 正常说话 /
#          纯文字 / 正常长句 / Speech 残留 / 情绪 emoji 保留
""",
}

for name, hdr in HEADERS.items():
    p = Path("/opt/dafeiyu/probe") / name
    if not p.exists():
        print(f"  跳过（不存在）: {name}")
        continue
    s = p.read_text(encoding="utf-8", errors="ignore")
    # 去掉原有 shebang 行，换成新的
    lines = s.splitlines()
    if lines and lines[0].startswith("#!"):
        body = "\n".join(lines[1:])
    else:
        body = s
    p.write_text(hdr + body + "\n", encoding="utf-8")
    print(f"  ✅ {name}")

# test_stt_real.py 也加
p = Path("/opt/dafeiyu/probe/test_stt_real.py")
if p.exists():
    s = p.read_text(encoding="utf-8", errors="ignore")
    hdr = '''"""STT 冒烟测试：用 Edge TTS 造 2 句已知文本，看识别对不对。

注意：模型路径写死在模块常量里，换机器要改 MP。
"""
'''
    lines = s.splitlines()
    body = "\n".join(lines[1:]) if lines and lines[0].startswith('"""') else s
    p.write_text(hdr + body, encoding="utf-8")
    print("  ✅ test_stt_real.py")
PYEOF

echo ""
echo "=== 4. 重新提交 ==="
git add probe/
git commit -q -m "chore(stt): 清理临时探路脚本，保留可复用的 5 个

剔除 13 个一次性排查脚本（asr_survey/stt_detail/stt_env/stt_load 等），
它们只是当时用来摸 AstrBot 的 STT 框架长什么样，没有长期价值。

保留并加了说明头（把踩坑结论写进文件本身，而不是 commit message）：
- install_stt.sh      模型安装；记录了 PyTorch 版/ONNX 版的区别和 bpe 缺失问题
- enable_stt.py       写 provider 配置；记录了 heredoc 在 docker exec 里失效
- test_stt_direct.py  端到端验证；记录了 ProviderManager 循环导入的绕法
- test_stt_acc.py     准确度回归；8 句已知文本的比对方法
- test_stt_clean2.py  清洗插件回归；为什么必须用断言而不是看日志" 2>&1 | tail -2

echo ""
echo "=== 5. 最终 ==="
git log --oneline | head -5 | sed 's/^/  /'
echo ""
echo "  文件: $(git ls-files | wc -l)   工作区: $(git status --porcelain | wc -l)"
echo ""
echo "  probe 里保留的 STT 脚本:"
git ls-files probe/ | grep -iE "stt|asr" | sed 's/^/    /'
