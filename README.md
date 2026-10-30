# 大肥鱼 QQ 机器人 · 本地部署

这是 **`nanbengxian-cyber/dafeiyu-qq-bot`** 的**本地部署与二次开发仓库**，
不是上游原创。上游是公开项目，本仓库记录「我在自己的 WSL2 机器上怎么把它跑起来、
改了什么、加了哪些插件」。

```
上游 upstream : nanbengxian-cyber/dafeiyu-qq-bot   ← 原作者，公开
本仓库 origin : zzyoxml/dafeiyu-deploy             ← 我的部署快照，私有
```

拉上游更新：

```bash
git fetch upstream
git log upstream/main --oneline -5        # 看上游新提交
git diff HEAD upstream/main --stat        # 看差异面
```

## 我加了什么

| 插件 | 作用 |
|---|---|
| `dsh-sing` | 点歌 AI 翻唱（yt-dlp → demucs 分轨 → RVC 换流萤音色）<br>带歌曲缓存：唱过的再点秒发，LRU 上限 100 首 |
| `dsh-voice-liuying` | 普通回复按 20% 概率自动出语音，Edge TTS → RVC 流萤音色 |
| `dsh-reply-guard` | 文字限流（10 条/60s）＋ 不回超过 10 句前的消息 |
| `dsh-awake` | 唤醒判定 |
| `dsh-mute` | 群内静音开关 |
| `dsh-qzone` | QQ 空间说说 |

另改了 3 个上游插件：`dsh-voice`（接入流萤音色 + Edge 7.3.1 兼容）、
`dsh-emotion`、`dsh-proactive`。

## 目录

```
docker-compose.yml        NapCat + AstrBot 编排
robot.env.example        环境变量模板（真实密钥见下方「密钥」）
_setup.sh                首次部署脚本
data/astrbot/plugins/    部署中的插件（自建 + 上游 + 第三方）
repo/plugins/            上游插件原始拷贝，用于对照改了哪些
patches/napcat.mjs       NapCat 补丁（跳过登录校验、WebUI 缓存）
probe/                   部署与验证脚本，含每个 bug 的复现/验证手段
                         （脚本在 Windows 侧生成后推入，用于 WSL2 部署排障）
```

## 密钥（重要）

真实密钥**不在本仓库**，以下文件已被 `.gitignore` 排除：

- `robot.env` —— 智谱 key、OneBot token、OFM key
- `cmd_config.json` —— 面板密码、JWT secret、ws_reverse_token
- `onebot11.json` —— token

首次部署：

```bash
cp robot.env.example robot.env
# 编辑 robot.env 填入你自己的 key
chmod 600 robot.env
```

## 不上传的大文件

仓库只含源码，约 7.4MB。以下约 3.2G 全被排除，由脚本重建：

| 排除项 | 体积 | 重建方式 |
|---|---|---|
| `sing/venv/` | ~1.9G | `probe/install_sing.sh` |
| `sing/model/`、`sing/rvc/` | ~590M | 同上（自动下载权重） |
| `temp/`、`stickerthief/`、`audio/` | ~680M | 运行期自动生成 |

## 部署

```bash
bash _setup.sh
docker compose up -d
```

详见 `probe/` 下脚本，每个都带注释说明解决的是什么问题。
