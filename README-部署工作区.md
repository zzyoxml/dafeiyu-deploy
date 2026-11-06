# 大肥鱼 QQ 机器人 · 部署工作区

本目录用于部署 [dafeiyu-qq-bot](https://github.com/nanbengxian-cyber/dafeiyu-qq-bot)（大肥鱼 QQ 机器人）。

## 部署包

**`dafeiyu-local/`** —— 本地 Windows + WSL2 部署包（不用云服务器）

| 文件 | 作用 |
|---|---|
| `部署指南-WSL本地.md` | **从这里开始读**。13 步完整流程：装 Docker → 拉码 → 一键初始化 → 扫码 → 配 AstrBot → 验证清单 |
| `docker-compose.yml` | NapCat + AstrBot 编排，端口只绑 127.0.0.1（本机才能访问） |
| `robot.env.template` | 运行配置模板，复制成 `robot.env` 后填你自己的 QQ 号 |
| `onebot11.json` | NapCat 的 OneBot 配置模板，setup.sh 会自动填随机 Token |
| `setup.sh` | 一键初始化：建目录 → 生成 Token → 装 59 个插件（幂等） |

## 最短路径

在 WSL 终端里：

```bash
cp -r "/mnt/d/xml/dafeiyu/dafeiyu-local" ~/dafeiyu-local
cd ~/dafeiyu-local
# 然后照着 部署指南-WSL本地.md 一步步走
```

## 两点必须知道

1. **用 QQ 小号，不要用主号。** 项目本身有封号风险，官方 README 明确警告。
2. **本地跑 = 电脑关了机器人就下线。** 真要 7×24 在线，后续得换云服务器部署。

细节和验证清单见 [dafeiyu-local/部署指南-WSL本地.md](dafeiyu-local/部署指南-WSL本地.md)。