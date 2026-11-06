# 大肥鱼 QQ 机器人 · 本地部署指南（Windows + WSL2 + Docker）

> 目标：在你自己的电脑上，把大肥鱼 QQ 机器人跑起来（NapCat 登录 QQ 小号 + AstrBot AI 框架 + 59 个插件）。
> 全程不需要云服务器、不需要域名、不需要备案。
> 本地跑的唯一代价：**电脑关机或休眠时机器人就下线**，想 7×24 挂着就得改云服务器。

---

## 0. 你需要自备的三样东西

| # | 东西 | 说明 |
|---|---|---|
| 1 | **QQ 小号** | ⚠️ 绝对不要用主号。这个机器人有封号风险，官方 README 明确警告 |
| 2 | **LLM API Key** | 聊天用。DeepSeek / 智谱 / OpenAI 都可以，便宜的 flash 类模型够用 |
| 3 | WSL2 环境 | 你已经有了。下面只需确认能进 Ubuntu |

可选（缺哪个少哪个功能，不影响其他）：视觉模型（看图/视频）、文生图、TTS、搜索接口。

---

## 1. 准备工作：把部署文件放进 WSL

本目录（Windows 上的 `dafeiyu-local`）里有 4 个文件，是整个部署的核心。
**不要**在 Windows 上直接跑 Docker，务必放在 WSL 的 Linux 文件系统里（性能好 10 倍）。

打开 WSL 终端（Ubuntu），执行：

```bash
# 从 Windows 盘拷进 WSL（注意 /mnt/d 对应 D 盘）
cp -r "/mnt/d/xml/大肥鱼/dafeiyu-local" ~/dafeiyu-local
cd ~/dafeiyu-local
ls -l        # 应该看到 docker-compose.yml / robot.env.template / onebot11.json / setup.sh
```

---

## 2. 在 WSL 里装 Docker

先确认已经有 Docker 了：

```bash
docker --version && docker compose version
```

**如果两条都有输出 → 跳过本步**，直接看第 3 步。

**如果没有**，在 WSL（Ubuntu/Debian）里装 Docker 官方版：

```bash
# 1) 删掉可能存在的冲突包
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 2) 装 Docker 官方版
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

> 如果你的 WSL 不是 Ubuntu（是 Debian 等），把上面命令里的 `ubuntu` 换成 `debian`，`$VERSION_CODENAME` 那段保持原样即可。

启动 Docker 服务：

```bash
sudo service docker start
docker --version
docker run --rm hello-world      # 出现 "Hello from Docker!" 说明 Docker 完全可用
```

**让 WSL 里的 Docker 开机自启（重要，否则重启电脑后要手动启动）：**

WSL 默认不带 systemd，需要手动开启。

```bash
# 检查是否已有 systemd 配置
cat /etc/wsl.conf 2>/dev/null

# 如果没有或没有 [boot] 段，执行：
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF

# 然后在 PowerShell 里重启 WSL：
#   wsl --shutdown
# 再重新打开 WSL，执行：
systemctl is-active docker    # 输出 active 说明 systemd 管理成功
```

---

## 3. 拉代码

```bash
cd ~
git clone https://github.com/nanbengxian-cyber/dafeiyu-qq-bot.git dafeiyu-qq-bot
ls ~/dafeiyu-qq-bot/plugins | wc -l    # 应该是 59（插件目录数）
```

---

## 4. 一键初始化（建目录 + 生成 Token + 装 59 个插件）

```bash
cd ~/dafeiyu-local
bash setup.sh ~/dafeiyu-qq-bot
```

脚本会打印一行 `OneBot Token（...）`，**请把它记下来**，第 6 步填 AstrBot 时要用。

---

## 5. 填配置（至少填 1 项）

```bash
nano robot.env
```

**必填（就一处）：**

```
DSH_ACL_OWNER=你的QQ号
```

- 这是「机器人主人」的 QQ 号，用来给群主权限。不填的话 `/权限` 等管理指令没人能用。
- 身份只按 QQ 号判定（群名片可以随时改，靠名字会认错人）。

**其他项**保持模板默认值即可，先跑起来再调。全部变量说明见同目录 `robot.env.template` 的注释。

> ⚠️ `robot.env` 里可能含 API Key，已设 `600` 权限，不要提交到任何 Git 仓库。

---

## 6. 启动

```bash
cd ~/dafeiyu-local
docker compose up -d
docker compose ps          # 两个容器都应该是 Up 状态
```

首次会拉镜像（NapCat ~1-2GB，AstrBot ~1GB），网络慢的话耐心等几分钟。

---

## 7. 扫码登录 QQ 小号

1. **Windows 浏览器**打开 `http://localhost:3001`（WSL2 会自动端口转发）
   - 端口只绑定了 `127.0.0.1`，只有本机能访问，局域网/公网都访问不到，这是安全的。
2. 进入 NapCat WebUI，扫码登录 **你的 QQ 小号**。
3. 登录成功后回终端确认：

```bash
docker logs napcat 2>&1 | grep -i "登录成功"
```

**关于掉线的实话**（README 实测数据）：QQ 账号会掉线，频率约 20~60 分钟一次，换 IP 救不回来。
这是协议端风控，不是配置错误。仓库自带看门狗脚本 `server/qq_watchdog.sh` 可以自动重启换码。
本地部署建议先手动重启观察，需要时我再帮你接上看门狗。

---

## 8. 配置 AstrBot（AI 框架）

浏览器打开 `http://localhost:6185`

### 8.1 首次进入：设管理员密码

首次访问会让你设置 AstrBot WebUI 的管理员密码，设完记住。

### 8.2 接入 QQ：OneBot V11 适配器

进入「消息平台」→「适配器」→ 添加 **OneBot V11**：

| 字段 | 填什么 |
|---|---|
| 连接方式 | **正向 WebSocket** |
| 主机 | `napcat`（⚠️ 不是 localhost —— 两个容器在同一 Docker 网络里，用容器名） |
| 端口 | `3001` |
| Token | 第 4 步 setup.sh 打印的那个 Token |

保存并启用。

**验证：** AstrBot 日志里应出现连接成功的记录：

```bash
docker logs astrbot --tail 50 | grep -i onebot
```

### 8.3 配置 AI 模型

进入「提供商」→ 添加模型（推荐 DeepSeek，便宜且够用）：

| 模型类型 | 配置 |
|---|---|
| **DeepSeek** | 选「OpenAI 兼容」，Base URL: `https://api.deepseek.com/v1`，填你的 API Key |

### 8.4 配置人格（Prompt）

进入「对话」→「人格」，编辑系统提示词。仓库自带的参考人格在 `~/dafeiyu-qq-bot/bridge/roles/小鲸鱼.md`，
可以直接复制过来改。建议先用官方那版跑通，确认效果后再按你的群风格调。

---

## 9. 验证清单

按顺序过一遍，全绿就算部署成功：

```bash
cd ~/dafeiyu-local

# ① 两个容器都在跑
docker compose ps

# ② NapCat 已登录
docker logs napcat 2>&1 | grep -i "登录成功" | tail -1

# ③ AstrBot 成功连上 OneBot
docker logs astrbot 2>&1 | grep -iE "onebot|napcat" | tail -5

# ④ 59 个插件全部加载无失败（这行输出 0 最重要）
docker logs astrbot 2>&1 | grep -ciE "加载失败|load fail|traceback"

# ⑤ 群里 @ 机器人说话，看它回
```

**群里实测顺序：**

| 测试 | 怎么测 | 期望 |
|---|---|---|
| 基本对话 | 群里 @ 它问个问题 | 有回复 |
| 主动插话 | 不 @它，聊几句它可能自己接话 | `DSH_DECIDE=1` 时会先判断该不该开口 |
| 权限系统 | 群里发 `/权限` | 你是 DSH_ACL_OWNER，能看到完整指令清单 |
| 记忆 | 问它"你还记得我吗" | `dsh-memory` 应能认出你 |
| 人味化 | 观察回复 | 短句、会分段、偶尔打错别字（`DSH_TYPO_RATE=0.06`） |

如果 ④ 的输出不是 0，看 `docker logs astrbot | grep -A 20 "加载失败"` 定位是哪个插件挂了。

---

## 10. 日常运维命令

```bash
cd ~/dafeiyu-local      # 所有命令都在这个目录下执行

docker compose ps              # 看状态
docker compose logs -f astrbot # 看 AstrBot 实时日志
docker compose restart astrbot # 重启 AstrBot
docker compose down            # 停止全部（数据保留）
docker compose up -d           # 重新启动
docker compose pull && docker compose up -d   # 更新镜像

# 改完 robot.env 后（重要）
docker compose up -d --force-recreate astrbot
```

> ⚠️ **改 `robot.env` 必须用 `--force-recreate`，不能用 `restart`。**
> `docker restart` 不会重读 `env_file`，你会发现改了配置却"没生效"。这是该项目的已知坑。

---

## 11. 电脑重启后的恢复

WSL2 + systemd 配置好之后（见第 2 步），重启电脑后：

1. 打开任意 WSL 终端（或者 Docker Desktop 启动也行）
2. 容器会自动拉起（`restart: always`）

如果发现容器没起来：

```bash
cd ~/dafeiyu-local
sudo service docker start    # 如果 systemd 没配好，每次都要手动
docker compose up -d
```

**要 7×24 挂着，必须做：**

- Windows 电源设置 → 睡眠 → **从不**（笔记本还要合盖不休眠）
- WSL 空闲不会自动关，但如果你只是关掉终端窗口，WSL 实例可能仍被系统回收 → 建议保持 Docker Desktop 常驻，或至少每天开机手动开一次终端

---

## 12. 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| `docker compose ps` 显示 Exit | 容器启动失败 | `docker compose logs --tail 50 napcat` 看报错 |
| 浏览器打不开 localhost:3001 | WSL2 端口转发未生效 | 先在 WSL 里 `curl -sI http://localhost:3001` 自测；WSL 内可用 IP |
| AstrBot 连不上 NapCat | 主机填错 | OneBot 适配器主机必须是 `napcat`（容器名），不是 `localhost` |
| QQ 频繁掉线 | QQ 风控 | 正常现象，README 实测 20~60 分钟掉一次；别用主号 |
| 改了 robot.env 没生效 | 用了 restart | 必须 `docker compose up -d --force-recreate astrbot` |
| 插件没加载 | 依赖缺失 | `docker logs astrbot | grep -A 10 "加载失败"` |
| 机器人不回话 | 可能没被触发 | 群里必须 @ 它；`/权限` 看指令；`docker logs astrbot -f` 实时看 |
| 内存不够 / 容器被 OOM | 机器内存 < 4GB | 关掉不用的功能插件，或加内存 |
| bot 跑着跑着变笨 | 上行发送挂了但下行还通 | README 的已知问题，靠 `server/observe` 探针检测 |

---

## 13. 关于这份部署的诚实说明

**我在你的机器上实测过什么：** 没有。执行命令的通道当前不可用，所以我是按官方
[部署手册](https://github.com/nanbengxian-cyber/dafeiyu-qq-bot/blob/main/docs/10-云服务器部署手册.md)
和 [插件清单](https://github.com/nanbengxian-cyber/dafeiyu-qq-bot/tree/main/deploy)
整理的本地化版本。每一处偏离手册的地方都标了原因（端口绑 127.0.0.1 更安全、插件用拷入而非挂载以免被 AstrBot 改动等）。

**你需要做的验证：** 严格按第 9 节的验证清单过一遍。任何一步输出和预期不符，
把那一步的命令和输出贴给我，我帮你定位。

**已知取舍：**

- 本地跑 = 电脑不关就 24 小时在线，关机就掉线。真要 7×24 还是得换云服务器。
- 机器人是"混在群里像真人"，行为上有一定主动性。上真实群之前建议先拉个小群或自己的测试号试跑几天，
  确认发言频率和风格你能接受，再放出去。
- 该项目插件依赖 AstrBot 内部结构，AstrBot 大版本升级可能需要改插件代码。锁定当前版本别乱升。

**已知限制（README 原话）：**

- 语音识别做不到（作者试过的渠道都欠费或没音频模型）
- 控制台服务端是明文 HTTP，无 TLS
- QQ 账号会被风控掉线，换 IP 没用