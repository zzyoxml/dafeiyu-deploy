#!/bin/bash
set -u
cd /opt/dafeiyu

echo "=== 1. 补充 gitignore（模型 + 运行状态）==="
cat >> .gitignore <<'EOF'

# STT 模型（231MB ONNX，由 probe/install_stt.sh 重建）
data/astrbot/stt-models/

# 插件运行期动态数据
data/astrbot/plugins/*/data/*_dyn.json
data/astrbot/plugins/*/data/*.json
EOFben
echo "  已追加"

echo ""
echo "=== 2. 撤销已跟踪的运行状态 ==="
git rm --cached -q data/astrbot/plugins/dsh-aiflavour/data/aiflavour_dyn.json 2>/dev/null && echo "  已取消跟踪 aiflavour_dyn.json" || echo "  （未跟踪）"

echo ""
echo "=== 3. 按功能拆分成 4 个提交 ==="

# --- 提交 1：STT 能力（provider 配置 + 模型安装脚本）---
git add probe/*stt* probe/test_stt* 2>/dev/null
git add .gitignore
git commit -q -m "feat(stt): 接入 SenseVoice 语音转文字

qq 群里发语音时机器人只会回「听不清」，因为 AstrBot 的 STT 开关
默认关闭且没有任何 STT provider。

选用 SenseVoiceSmall（魔搭 iic/SenseVoiceSmall-onnx）：
- 本地 ONNX 量化推理，CPU 0.16s/句，无需任何 API key
- 中文口语识别准确，实测「糖葫芦或者桂花糖藕」等完全一致
- 模型 231MB，由 probe/install_stt.sh 一键重建

探明的事：
- iic/SenseVoiceSmall 是 PyTorch 版（892MB），funasr_onnx 不吃 model.pt
  只吃 model_quant.onnx，所以必须下 -onnx 那个仓库
- ONNX 仓库缺 chn_jpn_yue_eng_ko_spectok.bpe.model，要单独从
  iic/SenseVoiceSmall 补 377KB 那个分词表，否则加载报 NOT_FOUND
- funasr_onnx 必须装进 AstrBot 主环境（provider 在容器主进程加载），
  只装 sing/venv 会报 No module named 'funasr_onnx'
- is_emotion=true 会把「(当前的情绪：HAPPY)」写进文本，不该开" 2>&1 | tail -2

# --- 提交 2：STT 清洗插件 ---
git add data/astrbot/plugins/dsh-stt-clean repo/plugins/dsh-stt-clean
git commit -q -m "feat(dsh-stt-clean): 清洗 SenseVoice 残留标签

SenseVoice 的 rich_transcription_postprocess 只在 BGM 时转成 🎼，
Singing 会把 <|Singing|> 原样留在文本里。群里有人唱歌时 LLM 收到
的是 <|Singing|>不敢轻皮黄颜红...，会把标签当内容。

插件在 on_llm_request 里剥掉残留标签，给唱歌/音乐加朴素前缀。

修过两个 bug：
- 原先写 if 'Singing' in tags，但 tags 存的是完整标签 '<|Singing|>'，
  集合是精确匹配，永远 False，前缀从没加上过
- BGM 已被后处理转成 🎼 emoji，正则找不到 <|BGM|>，补 emoji 检测

离线 9/9 场景通过（唱歌带词/纯 Singing/BGM/正常说话/情绪 emoji 保留）。" 2>&1 | tail -2

echo ""
echo "=== 4. 提交结果 ==="
git log --oneline | head -3 | sed 's/^/  /'
echo ""
echo "=== 5. stt-models 是否被挡住 ==="
git status --porcelain | grep stt-models | head -2 | sed 's/^/  /' || echo "  ✅ 已忽略"
echo ""
echo "  待提交剩余: $(git status --porcelain | wc -l)"
