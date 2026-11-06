# 唱歌技能包（搜歌 / 翻唱 / 发语音）

给跑着 **DSH** 的机器人加一项能力：有人点歌时，她自己上网搜、截片段（或用本机 RVC 模型换成指定音色翻唱），再作为语音发出去。

**这一版的重点是「换台机器也能装」**：目录自动探测、每处补丁都带降级、语音发送工具名可配置，不再绑定某台机器的 `D:\软件\qq-bridge` 和某个 qq-bridge 版本。

---

## 兼容性

| 场景 | 支持情况 | 说明 |
|---|---|---|
| qq-bridge（含 SnowLuma） | 全套 | 自动探测目录；补 MCP 注册、工具白名单、二代 toolMap、setup-dsh、角色卡 |
| qq-bridge 目录换了位置 | 全套 | 自动探测 `QQBRIDGE_ROOT` 环境变量 / 常见路径；也可 `-QqBridgeRoot` |
| qq-bridge 版本较新/较旧 | 尽力而为 | 补丁按「结构定位」（找数组、找锚点行）而不是整段字符串匹配；某处结构变了就跳过并提示手工，不会再中断安装 |
| 只有 DSH、没有 qq-bridge | MCP 部分 | 只复制文件 + 注册 MCP + 角色卡，跳过所有桥接补丁（通用模式） |
| NapCat / Lagrange 等 OneBot 后端 | MCP 部分 | 同上（通用模式）。技能只依赖「有一个能发语音的 OneBot 工具」，不依赖具体框架 |
| 语音发送工具不叫 `qq_send_voice` | 支持 | `-VoiceTool send_voice` 之类；写进 `mcp-sing.js` 默认值和角色卡 |
| QQ 客户端装在含空格的路径 | 需先处理 | 注入式加载器（NapCat）会报 `Cannot find module 'D:\Program ...loadNapCat.js'`，见下方 FAQ |
| macOS / Linux | 未支持 | 脚本是 PowerShell，且 RVC/语音链路按 Windows 布局写的 |

> 这里说的「QQ 版本」指机器人那一侧（qq-bridge / SnowLuma / NapCat / OneBot 实现）的结构差异。**QQ 客户端本身的版本（NT 版本、hook 兼容）不在这个包的范围**——那是加载器（SnowLuma / NapCat）的升级问题。

### 非 qq-bridge 后端（NapCat / Lagrange …）

走通用模式：只装 MCP + 角色卡，桥接补丁自动跳过。完整步骤、端口/token 核对、发语音能力验证、验收清单和故障对照都在
[docs/NAPCAT-INTEGRATION.md](docs/NAPCAT-INTEGRATION.md)。

关键三步：

```powershell
powershell -ExecutionPolicy Bypass -File .\check-qq-env.ps1     # 先看 QQ 路径有没有空格、后端识别到没
powershell -ExecutionPolicy Bypass -File .\probe-onebot.ps1 -HttpUrl "http://127.0.0.1:3000" -Token "<token>"
powershell -ExecutionPolicy Bypass -File .\install.ps1 -VoiceTool "<你框架里发语音的工具名>"
```

---

## 目录结构

```
dafish-sing-skill-20261023/
├─ check-qq-env.ps1            # 装之前先跑：识别后端、QQ 路径、端口、依赖（只读）
├─ probe-onebot.ps1            # OneBot 探针：登录/版本/在线，可选实测发文本、发语音
├─ install.ps1                 # 一键安装（支持 -DryRun 预览，末尾打印结果汇总表）
├─ verify.ps1                  # 装完自检：逐项 OK / WARN / FAIL
├─ uninstall.ps1               # 回滚补丁（自动找目录）
├─ README.md
├─ payload/
│  ├─ src/mcp-sing.js          # MCP 服务器：sing_probe / sing_search / sing_cover
│  ├─ sing/cover.py            # RVC 推理驱动（目录相对自身定位）
│  ├─ sing/convert_model.py    # safetensors -> pth 转换
│  ├─ sing/rvc_cli/            # RVC 推理代码（不含模型）
│  ├─ sing/requirements*.txt   # Python 依赖（含一份完整 freeze 对照）
│  └─ roles/sing-skill-section.md # 追加到角色卡的段落（{{VOICE_TOOL}} 安装时替换）
├─ models/sing/                # 三份模型，安装时自动铺到目标目录
└─ docs/
   ├─ cordis-mcp-sing.yml      # 注册片段（脚本自动写，供核对）
   └─ NAPCAT-INTEGRATION.md    # 非 qq-bridge 后端（NapCat 等）接入清单
```

---

## 前置条件

| 项 | 要求 |
|---|---|
| 系统 | Windows 10/11 |
| 已有环境 | DSH 能启动；机器人能在 QQ 收消息 |
| Python | 3.10 ~ 3.12（推荐 3.12），能创建 venv |
| 磁盘 | 代码 + venv 约 2～3 GB，模型另算约 640 MB |
| 显卡 | 可选。NVIDIA 4 GB 以上翻唱约 10 秒一首；纯 CPU 也能跑但很慢 |
| 网络 | 能访问 B 站 / YouTube（搜歌）、huggingface 镜像（下模型） |

没有 GPU 也能用 `mode=original`（原唱片段），只依赖 yt-dlp + ffmpeg。

---

## 安装

```powershell
# 0) 先体检：这机器是什么后端、QQ 装哪、端口/依赖齐不齐（只读）
powershell -ExecutionPolicy Bypass -File .\check-qq-env.ps1

# 1) 再看安装计划（不写任何文件）
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun

# 2) 真装（绝大多数情况不用带参数，脚本会自己找）
powershell -ExecutionPolicy Bypass -File .\install.ps1

# 目录/工具名特殊时：
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -QqBridgeRoot "E:\bots\qq-bridge" -VoiceTool "send_voice" -ProfileName desktop
```

### 参数

| 参数 | 默认 | 作用 |
|---|---|---|
| `-QqBridgeRoot` | 自动探测 | 机器人根目录（要含 `src\bridge.js` 或作为通用安装目标） |
| `-DshProfile` | 自动探测 | DSH profile 目录；也可用 `-ProfileName desktop` |
| `-ProfileName` | — | 按 profile 名字选，优先级低于 `-DshProfile` |
| `-NodeExe` | 自动探测 | `node.exe` 路径（写进 MCP 注册） |
| `-RoleFile` | 自动探测 | 角色卡文件；给了就不猜 |
| `-VoiceTool` | `qq_send_voice` | 发语音的工具名，写进 `mcp-sing.js` 与角色卡 |
| `-SkipRole` / `-SkipModels` | — | 跳过角色卡 / 跳过模型复制 |
| `-DryRun` | — | 只打印计划 |

### 脚本会做什么

1. 探测机器人目录、node.exe、DSH profile（打印出来给你确认）
2. 复制 `mcp-sing.js`、`cover.py`、`convert_model.py`、`rvc_cli/`（按 `-VoiceTool` 改写默认工具名）
3. 铺模型（已存在则跳过）
4. 往 `cordis.patch.yml` 追加 `mcp-sing` 注册块
5. 若有 `qq-agent-presets`，把 `mcp__sing__` 插进 `SAFE_PREFIXES`（找数组起始位置插入，不依赖整行格式）
6. 若有 `bridge.js`，在二代 `toolMap` 里补 `singCover`（依次尝试 `waitMessages` / `sendImage` / `sendMessage` 三个锚点）
7. 若有 `setup-dsh.mjs` 的 `MANAGED_MCP_IDS`，把 `mcp-sing` 加进去
8. 往角色卡追加唱歌段落（BEGIN/END 标记，重复跑不会叠加）

每一步都会进最后的**结果汇总表**（完成 / 跳过 / 需手工），所有改动先备份为 `*.bak-sing-skill-<时间>`。

---

## 装完之后

```powershell
# 装 Python 依赖
cd <机器人目录>\sing
python -m venv venv
.\venv\Scripts\python -m pip install --upgrade pip
.\venv\Scripts\python -m pip install -r requirements.txt

# 自检（只读，不改文件）
powershell -ExecutionPolicy Bypass -File .\verify.ps1

# 重启 DSH（MCP 工具列表启动时加载）
```

`requirements.txt` 默认是 **CUDA 12.1 版 torch**；没有 N 卡就把 `torch` / `torchaudio` 的 `+cu121` 去掉，否则装不上。装完对不上就看 `requirements-lock.txt`（一台跑通机器上的完整 freeze）。

### 模型

| 文件 | 目标位置 | 大小 |
|---|---|---|
| 声音模型 `liuying.pth`（RVC v2 40k 带 f0） | `sing\model\liuying.pth` | ~53 MB |
| 音高提取 `rmvpe.pt` | `sing\rvc_cli\rvc\models\predictors\rmvpe.pt` | ~173 MB |
| 内容特征 `contentvec` | `sing\rvc\models\embedders\contentvec\` | ~361 MB |

包里已经带好了，install.ps1 会自动铺；目标已存在则跳过，不覆盖你自己的模型。

换音色：把任意 RVC v2 模型转成 `.pth` 放进 `sing\model\`，改 `mcp-sing.js` 的 `AI_VOICE_MODEL`，或用 `convert_model.py`：

```powershell
cd <机器人目录>\sing
.\venv\Scripts\python convert_model.py model\xxx.safetensors model\xxx.pth
```

只做原唱片段可以跳过；缺模型时 `sing_cover(mode=ai)` 会明确报「缺哪样」，不会静默退回原唱。

### 外部依赖（yt-dlp / ffmpeg）

`mcp-sing.js` 的查找顺序：**环境变量 → 机器人目录下常见位置 → PATH 同名 exe**。

- `DSH_YTDLP` / `DSH_FFMPEG` 环境变量
- `<机器人目录>\video\venv\Scripts\yt-dlp.exe`、`<机器人目录>\video\bin\ffmpeg.exe`
- 都没有就用 PATH 上的 `yt-dlp.exe` / `ffmpeg.exe`

```powershell
setx DSH_YTDLP  "C:\tools\yt-dlp.exe"
setx DSH_FFMPEG "C:\tools\ffmpeg.exe"
```

设完要重启 DSH 才会传给 MCP 进程。

---

## 验证

1. `verify.ps1`：逐项列出目录、文件、venv/torch、yt-dlp/ffmpeg、cordis 注册、白名单、toolMap 的状态。
2. 重启后让她自查：`sing_probe` 返回每项依赖是否就绪。
3. 对她说「唱一首《生日快乐》」：她会 `sing_search` → `sing_cover` → 用 `-VoiceTool` 指定的工具发出去。纯文本环境产物在 `<机器人目录>\audio\sing-*.mp3`。

---

## 常见问题

**弹窗 `A JavaScript error occurred in the main process` / `Cannot find module 'D:\Program ...loadNapCat.js'`**

这不是本技能包引起的，是 **QQ 客户端装在含空格的路径**（`D:\Program Files\Tencent\QQNT\...`）后，注入式加载器（NapCat 一类）启动时把命令行按空格切断，Node 只拿到 `D:\Program`。

三种处理，按成功率排：

1. **把 QQ 重装到无空格路径**（如 `D:\QQNT`）——最稳；重装后 QQ 版本目录会变，加载器也要按新路径重新挂一次。
2. **升级加载器/安装器到最新版**（新版已对路径加引号），并按它的官方步骤重新注入。
3. 临时绕：用短路径（8.3 名称）启动，例如 `for %I in ("D:\Program Files") do @echo %~sI` 拿到 `D:\PROGRA~1`，再用它替换命令行里带空格的路径。

自查：`check-qq-env.ps1` 会在「QQ 路径空格」这一行直接标 FAIL 并把上面这段提示打出来。

**搜歌失败、B 站 412**
B 站对匿名抓取有反爬。给 yt-dlp 配 cookies（`--cookies-from-browser chrome` 或导出 `cookies.txt`），或换 YouTube 源（脚本本身 B 站优先、YouTube 兜底）。

**`sing_cover(mode=ai)` 报缺东西**
按报错补齐 venv / torch / rvc_cli / cover.py / model。它会一次列全。

**torch 装不上 / 版本冲突**
锁 `torch 2.5.1+cu121` + `transformers 4.46.3`。升到 torch 2.6+ 配 transformers 5.x 理论可行但 RVC 未验证。

**装完没有 sing 工具**
- 确认重启过 DSH；
- `cordis.patch.yml` 里要有 `mcp-sing` 块且 `command` 指向真实 node.exe；
- 工具守卫拦截时，看 `qq-tool-restrict.mjs` 的 `SAFE_PREFIXES` 是否有 `mcp__sing__`；
- 跑 `verify.ps1` 一眼看出是哪一步没成。

**汇总表里有「需手工」**
说明那台机器的文件结构和预期不同（新版 qq-bridge 改了结构）。按说明手工补那一处即可，其它步骤已经生效。

**显存不足**
一次只跑一段。显存 < 4 GB 建议只用 `mode=original`，或把 `cover.py` 的推理设备改成 CPU。

**卸载**
```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```
只回滚注册与补丁，`sing\` 下的 venv、模型、代码不动。角色卡里的 BEGIN/END 段落手工删。

---

## 已知边界

- 片段最长 4 分钟（240 秒），不传 `seconds` 默认 30 秒，`startSeconds` 可指定起点。
- 只下音轨不下视频；产物进 `audio/` 语音库，受语音库时长/体积/频率限制约束。
- 内容版权由使用者自行负责。

---

## 可选：检索索引（让音色更像原声）

包里的 `liuying.pth` 已经能直接用。如果你还想要更高的相似度，可以额外放一个 faiss 检索索引：

1. 拿到 `liuying.index`（约 523 MB，单独分发）
2. 放到 `qq-bridge\sing\model\liuying.index`
3. 不需要改任何配置：`cover.py` 会自动发现它并把 `index_rate` 从 0 提到 0.75

注意：faiss 的 C++ 层读不了中文路径，`cover.py` 检测到路径含非 ASCII 字符时会自动把索引复制到 `%TEMP%\rvc-index\` 再用，不用你手动处理。