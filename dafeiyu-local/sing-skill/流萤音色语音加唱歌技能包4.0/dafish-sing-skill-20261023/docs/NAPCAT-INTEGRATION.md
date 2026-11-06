# NapCat（以及其它 OneBot 后端）接入清单

这份清单解决一件事：**技能包在非 qq-bridge 环境里怎么落地**。
技能本身只依赖两样东西——「能生成音频文件」和「有一个能发语音的 OneBot 工具」。桥接补丁全是可选的。

> 说明：下面的命令按 OneBot 11 通用口径写。不同 NapCat 版本在**录音段字段**和**默认端口**上会有差异，每一步都给了验证办法，对不上就按验证结果调整。

---

## 0. 先体检

```powershell
powershell -ExecutionPolicy Bypass -File .\check-qq-env.ps1
```

重点看四行：

| 行 | 期望 | 不对怎么办 |
|---|---|---|
| `QQ NT 安装目录` | 找到目录 | 没找到就看是不是绿色版/非常规路径，手工核对 |
| `QQ 路径空格` | **无空格** | 见下面第 1 节 |
| `识别到的后端` | 出现 `napcat` | 没出现说明注入没成，或 NapCat 不在 PATH |
| `本机监听端口` | 有 3000/3001 或你配置的端口 | 没有说明 OneBot 服务没起来 |

---

## 1. QQ + 注入：先把路径坑排掉

### 症状

```
A JavaScript error occurred in the main process
Error: Cannot find module 'D:\Program
Files\Tencent\QQNT\versions\9.9.30-48762\resources\app\loadNapCat.js'
```

### 原因

QQ 装在含空格的路径（`D:\Program Files\...`），加载器启动时命令行被空格切断，Node 只拿到 `D:\Program`。

### 三种处理（按成功率排）

1. **把 QQ 重装到无空格路径**，例如 `D:\QQNT`。
   重装后版本目录会变（`versions\9.9.xx-xxxxx`），加载器要按新路径重新挂一次。
2. **升级加载器/安装器到最新版**。新版一般会把路径加引号；升级后按它的官方步骤重新注入。
3. **临时用 8.3 短路径**：

   ```cmd
   for %I in ("D:\Program Files") do @echo %~sI
   ```

   拿到 `D:\PROGRA~1` 这类短名，替换命令行里带空格的那一段。

### 验收

重启 QQ 后没有任何 JS 报错弹窗，且：

```powershell
Get-ChildItem "<QQ目录>\resources\app" -Filter "*NapCat*"
```

能列出加载器文件。

---

## 2. NapCat 的 OneBot 服务

### 配置位置

NapCat 的配置一般在它的 `config` 目录下，文件名形如 `onebot11_<QQ号>.json`，里面分 `httpServers` / `websocketServers`：

- **HTTP**：给「一次性请求」用（发消息、查状态），要记住端口和 `accessToken`
- **WS**：给「事件推送」用（收消息）

端口别和其它服务打架。如果这台机器同时跑着 qq-bridge/SnowLuma，注意 3000/3001 可能已经被占——用 `check-qq-env.ps1` 的端口那行确认，或直接改成别的端口。

### 验收：探针

```powershell
powershell -ExecutionPolicy Bypass -File .\probe-onebot.ps1 `
  -HttpUrl "http://127.0.0.1:3000" -Token "<你的token>"
```

它只做只读检查：`get_login_info` / `get_version` / `get_status`，把账号、版本、在线状态打出来。
能拿到 `user_id` 就说明 HTTP 通道、token、端口全通了。

可选的实发测试（会真的发一条消息给对方）：

```powershell
# 发一条文本
.\probe-onebot.ps1 -HttpUrl "http://127.0.0.1:3000" -Token "<token>" -UserId <你的QQ>

# 再试一条语音（验证 record 段能不能用）
.\probe-onebot.ps1 -HttpUrl "http://127.0.0.1:3000" -Token "<token>" `
  -UserId <你的QQ> -VoiceFile "D:\软件\qq-bridge\audio\sing-xxx.mp3"
```

---

## 3. 确认「发语音」这一环

技能最后一步是「把音频发出去」，这一步在不同后端里差异最大。按顺序确认：

1. **有录音段能力**：`record` 段，字段可能是 `file`（本地路径 / `file://` URL）或 `base64`。
2. **有发送 action**：`send_private_msg` / `send_group_msg` / `send_msg` 三者任选其一。
3. **权限/白名单**：部分实现要求目标在好友/群白名单里，且不允许发任意本地路径（只允许它的数据目录）。

用探针的 `-VoiceFile` 实测最直接：成功会返回 `message_id`；失败通常给 `retcode` + `wording`，按提示改（文件格式、路径限制、时长上限）。

**不同后端的「工具名」不一样**，装技能时要告诉它用哪个：

| 你的环境 | `-VoiceTool` 取值 |
|---|---|
| qq-bridge（本仓默认） | `qq_send_voice` |
| 自己封装的 MCP 工具 | 你实际暴露的名字，例如 `send_voice`、`qq_send_record` |
| 只有 OneBot HTTP、没有封装工具 | 先自行包一层 MCP/工具，再把这个名字填进来 |

---

## 4. 装技能（通用模式）

没有 `src\bridge.js` 时，安装脚本会自动进「通用模式」：只复制文件、注册 MCP、追加角色卡，桥接类补丁全部跳过并记进汇总表。

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\install.ps1 -VoiceTool "<你上一步确定的名字>" `
  -QqBridgeRoot "<你希望放 sing/ 的目录>" -ProfileName desktop
```

装完：

```powershell
cd <目录>\sing
python -m venv venv
.\venv\Scripts\python -m pip install --upgrade pip
.\venv\Scripts\python -m pip install -r requirements.txt   # 无 N 卡先去掉 +cu121

powershell -ExecutionPolicy Bypass -File .\verify.ps1
```

然后重启 DSH（MCP 工具列表启动时加载）。

---

## 5. 让机器人真的用起来

技能装好后有三个工具：`sing_probe` / `sing_search` / `sing_cover`。

- 角色卡段落里默认写的是 `{{VOICE_TOOL}}`，安装时会被替换成你传的 `-VoiceTool`；
- 如果你的机器人不是 qq-bridge，**角色卡要在你自己的提示词里手工贴一段**，把工具名改成实际的；
- 结束时 `sing_cover` 会返回 `next: 用 <工具> 传 voice="xxx.mp3" 发出去`，工具名同样来自这个配置。

---

## 6. 验收清单

| # | 检查 | 通过标准 |
|---|---|---|
| 1 | QQ 启动无 JS 报错 | 没有 `Cannot find module ... loadNapCat.js` |
| 2 | `check-qq-env.ps1` | 有 `QQ NT 安装目录`、`QQ 路径空格=无空格`、后端里出现 napcat |
| 3 | `probe-onebot.ps1`（只读） | 返回 `user_id` / `version` / `online` |
| 4 | 文本实发 | 对端收到消息，返回 `message_id` |
| 5 | 语音实发 | 对端收到语音条；日志若提示路径限制，改用它的数据目录 |
| 6 | `verify.ps1` | FAIL=0（WARN 按说明处理） |
| 7 | DSH 重启后工具列表 | 能看到 `sing_probe` / `sing_search` / `sing_cover` |
| 8 | 让它唱一首 | 搜歌 → 生成 → 用正确工具名发出语音 |

---

## 7. 故障对照

| 现象 | 多半是 | 处理 |
|---|---|---|
| `Cannot find module 'D:\Program ...loadNapCat.js'` | QQ 路径含空格 | 重装到 `D:\QQNT` / 升级加载器 / 用 8.3 短路径 |
| 探针 401 | token 不匹配 | 对齐配置里的 `accessToken`，或该服务未启用 HTTP |
| 探针连接失败 | 端口不对 / 服务没起 | `check-qq-env.ps1` 看监听端口；确认 NapCat 已登录 |
| 发送返回 405 | 请求方法/路径不对 | OneBot 是 `POST /` + `{action,params}`；有的实现也吃 `POST /<action>`，两个都试 |
| 语音发送失败 | 录音段字段不一致 / 文件路径受限 | 换 `file` 与 `base64` 两种写法；或把文件放进它的数据目录 |
| 装完没有 sing 工具 | 没重启 DSH / cordis 没注册 | `verify.ps1` 看 `cordis.patch.yml` 那行 |
| 汇总表有「需手工」 | 该版本结构变了 | 按说明手工补那一处，其余步骤已生效 |
