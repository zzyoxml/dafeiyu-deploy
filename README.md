# 大肥鱼 QQ 机器人 · 本地部署与二次开发

基于 **[nanbengxian-cyber/dafeiyu-qq-bot](https://github.com/nanbengxian-cyber/dafeiyu-qq-bot)**（上游，公开）的
**WSL2 / Docker 本地部署快照**。这里记录的是「我在自己机器上怎么把它跑起来、改了什么、加了哪些插件」，
不是上游原创。

```
upstream : nanbengxian-cyber/dafeiyu-qq-bot   上游原作者
origin   : zzyoxml/dafeiyu-deploy             本部署仓库
```

> 本仓库只存**部署配置 + 插件源码 + 复现脚本**，不含运行期数据、模型权重、密钥。
> 克隆后需先手动加远程（git 不会把 remote 存进仓库）：
>
> ```bash
> git remote add upstream https://github.com/nanbengxian-cyber/dafeiyu-qq-bot.git
> git fetch upstream && git log upstream/main --oneline -5
> git diff HEAD upstream/main --stat
> ```

---

## 快速开始

```bash
cp robot.env.example robot.env    # 填自己的 key（见「密钥」）
bash _setup.sh                    # 首次部署：建目录、生成 token、装插件
docker compose up -d
```

日常操作（Windows 侧双击即可）：`start.bat` / `status.bat` / `stop.bat`，
详见 [使用说明.md](使用说明.md)、[README-部署工作区.md](README-部署工作区.md)。

---

## 架构

```
QQ ── NapCat（Docker）── AstrBot（Docker）
                            │
                            ├── 67 个 dsh-* 插件（data/astrbot/plugins/）
                            ├── LLM 网关：DSH NEXT 127.0.0.1:8326
                            │            └─ 容器经 llm-forward.mjs 转发到 18901
                            ├── 生图：智谱 cogview / Agnes / pollinations
                            ├── 语音：Edge TTS + RVC 流萤音色
                            └── 唱歌：yt-dlp + demucs + RVC
Windows 侧：guard.sh 守护 + llm-forward.mjs 转发 + 开机自启
```

---

## 功能地图（67 个插件）

> 完整清单在 [data/astrbot/plugins/](data/astrbot/plugins/)。
> 下面是按用途分组的主要能力，**标 ★ 的是有独立文档的**。

### 🎨 多媒体（画图 / 语音 / 唱歌 / 视频）★

| 插件 | 能力 | 文档 |
|---|---|---|
| **dsh-imagegen** ★ | **AI 文生图**：群友 `/画图 描述`、自然语言「画一只猫」、LLM 工具、模型只嘴上答应时的兜底、主动概念草图；**机器人自己还有 5% 概率把当前群聊话题画成一张图**；主备模型降级、冷却、并发、统一画风 | [画图功能搭建与接入指南.md](docs/画图功能搭建与接入指南.md) |
| dsh-voice | TTS 语音（Fish Audio / 悟声 / Edge 兜底），`/说话`、LLM 工具 | |
| dsh-voice-liuying | 普通回复 **20% 概率自动出语音**，Edge TTS → RVC 换流萤音色，`/流萤说` | [自建插件说明.md](docs/自建插件说明.md) |
| dsh-sing | 点歌 AI 翻唱：yt-dlp 搜歌 → demucs 分轨 → RVC 流萤音色，带 LRU 歌曲缓存 | 同上 |
| dsh-video | 抽帧理解群视频、`/做视频` 后台出片、概念短片 | |
| dsh-sticker / dsh-steal | 表情包贴纸；偷群里反复发、能看懂意思的表情包 | |
| dsh-vischain / dsh-imgctx / dsh-listen / dsh-stt-clean | 识图主备链、图片上下文、语音转写、STT 结果清洗 | |

### 🧠 人格 / 情绪 / 意志

`dsh-persona-core`（人格核心）、`dsh-mind`（内在状态总线）、`dsh-emotion`（单一主情绪）、
`dsh-will`（被踩线时的执行层）、`dsh-desire`（分层动机）、`dsh-agency`（自主意志协调）、
`dsh-selfaware`（机器自我感知）、`dsh-selfworth`（不认账/不自贬）、`dsh-fatigue`（话题疲劳）、
`dsh-interest`（兴趣时间线）、`dsh-social`（社交距离）、`dsh-poke`（戳一戳）、
`dsh-scene`（群级背景与作息）、`dsh-drift`（注意力漂移）。

### 💬 说话方式 / 去 AI 味

`dsh-decide`（该不该插话）、`dsh-human`（真人打字形状）、`dsh-humanizer`、`dsh-aiflavour`（拦截说教腔）、
`dsh-typo`（低概率同音错别字）、`dsh-noise`（真人噪点）、`dsh-style`（模仿本群短句）、
`dsh-slang`（群聊黑话学习）、`dsh-glossary`（黑话词表）、`dsh-homophone`（谐音识别）、
`dsh-quote` / `dsh-quoteref`（引用关系与引用回复）、`dsh-mention`（智能 @）、
`dsh-merge`（艾特风暴重扫）、`dsh-followup`（免艾特续聊）、`dsh-repeat`（复读）、
`dsh-clarify`（语境疑问闸门）、`dsh-spine`（累积牵引感知）、`dsh-effect`（回复效果观察）。

### 🛡️ 安全 / 边界 / 权限

`dsh-acl`（指令权限三档）、`dsh-guard`（违规判定与禁言）、`dsh-claimguard`（拦虚构战绩/支配称呼）、
`dsh-armor`（防破甲/提示词注入）、`dsh-leakguard`（防系统提示词泄露）、`dsh-factguard`（自身属性事实表）、
`dsh-selfguard`（出口自制力）、`dsh-reply-guard`（限流 10 条/60s）、`dsh-mute`（群内禁言）、
`dsh-joinguard`（入群 AI 审核）、`dsh-welcome`（入群欢迎）、`dsh-pay`（收款引导）、
`dsh-awake`（唤醒判定）、`dsh-ctxclean`（清理陈旧注入块）。

### 📚 记忆 / 知识 / 联网

`dsh-memory`（分层长期记忆）、`dsh-awareness`（群事件感知）、`dsh-awareness`、`dsh-initiate`（冷场主动开口）、
`dsh-proactive`（兴趣探头）、`dsh-web`（联网搜索）、`dsh-qzone`（QQ 空间说说）、
`dsh-fwd`（合并转发消息）、`astrbot_plugin_anysearch`（免费联网检索）。

> 早期 6 个自建插件的**设计思路与踩坑实录**见 [自建插件说明.md](docs/自建插件说明.md)。

---

## LLM 网关与渠道修复

- 容器访问不到 Windows 回环，由 [llm-forward.mjs](llm-forward.mjs) 把 `0.0.0.0:18901` 转发到
  **DSH NEXT 网关 `127.0.0.1:8326`**（2026-11-06 从旧 OFM 18900 切过来）。
- AstrBot 主力模型 `trae/qwen3.8-flash`，其余可用模型见 `cmd_config.json`。
- **CodeBuddy CN（buddy 渠道）`400/11128` 修复**：上游对 DSH 系统提示词做指纹匹配，
  本地给 `dsh-our-free-model` 插件打了补丁并做成一键脚本。
  完整定位过程与复现表格见 [docs/buddy-channel-fix.md](docs/buddy-channel-fix.md)，
  补丁脚本 [probe/apply-buddy-channel-fix.mjs](probe/apply-buddy-channel-fix.mjs)。

---

## 目录

```
docker-compose.yml          NapCat + AstrBot 编排
robot.env.example           环境变量模板（真实密钥不进仓库）
_setup.sh                  首次部署脚本
data/astrbot/plugins/       部署中的插件（自建 + 上游 + 第三方，67 个）
repo/plugins/              上游插件原始拷贝，用于对照改了哪些
patches/                   NapCat 等第三方组件适配
docs/                      专题文档（画图接入、自建插件、buddy 修复、wslconfig）
probe/                     WSL 部署/排障脚本 + 一键补丁脚本
dafeiyu-local/             Windows + WSL2 本地部署包（指南、模板、探针）
win/ wsl/                   Windows / WSL 侧启停与守护脚本
*.bat / guard.sh / ...      工作区根目录的日常操作入口
```

---

## 密钥（重要）

真实密钥**不在本仓库**，以下文件已被 `.gitignore` 排除：

- `robot.env` —— 智谱 key、OneBot token、网关 token
- `cmd_config.json` —— 面板密码、JWT secret、ws_reverse_token
- `onebot11.json`、运行期图片/日志/`*.pth` 模型权重

首次部署：

```bash
cp robot.env.example robot.env
# 编辑 robot.env 填入你自己的 key
chmod 600 robot.env
```

> ⚠️ 含真实凭据的本地文件与运行期图片在 `.gitignore` 里已逐项排除；
> 提交前脚本 `probe/secret_audit.sh`、`probe/find_secrets.sh` 可再扫一遍。

---

## 不上传的大文件

仓库只含源码（约 7.4MB）。以下约 3.2G 全被排除，由脚本重建：

| 排除项 | 体积 | 重建方式 |
|---|---|---|
| `sing/venv/` | ~1.9G | `probe/install_sing.sh` |
| `sing/model/`、`sing/rvc/` | ~590M | 同上（自动下载权重） |
| `temp/`、`stickerthief/`、`audio/` | ~680M | 运行期自动生成 |

流萤唱歌技能包（代码部分）在 [dafeiyu-local/sing-skill/](dafeiyu-local/sing-skill/)；
模型权重按包内 README 重新下载。

---

## 深入阅读

| 文档 | 内容 |
|---|---|
| [画图功能搭建与接入指南.md](docs/画图功能搭建与接入指南.md) | **AI 画图**：怎么搭、群友怎么用、5% 随机生图、防刷、FAQ |
| [自建插件说明.md](docs/自建插件说明.md) | 早期 6 个自建插件的设计与踩坑 |
| [buddy-channel-fix.md](docs/buddy-channel-fix.md) | buddy 渠道 400/11128 拦截的定位与补丁 |
| [使用说明.md](使用说明.md) | 日常双击操作、面板地址、群里怎么用 |
| [README-部署工作区.md](README-部署工作区.md) | WSL2 本地部署包说明 |
| [patches/README.md](patches/README.md) | 对第三方组件做过哪些本地适配 |
| [probe/](probe/) | 部署与排障脚本，每个都带注释说明解决什么问题 |

---

## 已知限制

- **CPU 推理**：60 秒的歌约 3.5 分钟（demucs 占大头）；RVC 只能单实例（`asyncio.Lock`）。
- **Edge TTS 可能间歇 403**：微软校验 Chromium 版本号，需 `edge-tts >= 7.3.1`；
  合成强制走挂载卷 `sing/venv`，容器重建不受影响。
- **`docker restart` 不重读 `env_file`**：改 `robot.env` 后必须
  `docker compose up -d --no-deps --force-recreate astrbot`（见画图指南 2.3 节）。
- **本地部署 = 电脑关了机器人就下线**；QQ 有风控，建议用小号。
- 部分渠道（如 WorkBuddy）需要单独登录凭据，未配置时返回「未配置凭据」。

---

## 相关仓库

- 上游：[nanbengxian-cyber/dafeiyu-qq-bot](https://github.com/nanbengxian-cyber/dafeiyu-qq-bot)
- 本部署：[zzyoxml/dafeiyu-deploy](https://github.com/zzyoxml/dafeiyu-deploy)
- 免费模型插件问题参考：[Ebony-Vinyl/dsh-our-free-model#542](https://github.com/Ebony-Vinyl/dsh-our-free-model/issues/542)
