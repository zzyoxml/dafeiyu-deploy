# wsl/ —— WSL 内部脚本

这些脚本原本放在 WSL 的 `/root/` 下，不在 git 里。WSL 磁盘万一损坏
或需要重建实例，这些逻辑就没了，所以归档到这里。

部署时复制回去：

```bash
cp wsl/*.sh /root/ && chmod +x /root/*.sh
```

## 文件

| 文件 | 作用 | 谁调用 |
|---|---|---|
| `start-bot.sh` | 一键启动：查 docker → 恢复 `restart=always` → 起容器 → 拉起 anchor → 轮询 WebUI | `win/start.bat` |
| `stop-bot.sh` | 一键停止：停 WSL 内 guard → 停两个容器 → 确认 | `win/stop.bat` |
| `status-bot.sh` | 状态检查：docker/容器/anchor/心跳/WebUI/WS 连接/今日消息数 | `win/status.bat` |
| `anchor.sh` | 保活循环，每 20 秒巡检，写心跳 `/root/anchor.beat` | `start-bot.sh` 用 `setsid` 拉起 |
| `live-log.sh` | 实时对话日志，`[A]`=AstrBot `[Q]`=NapCat | 手动 `bash /root/live-log.sh` |
| `do_push.sh` | git push（从 `/root/.gh_token` 读 PAT） | 手动 |
| `push_now.sh` | 推送兜底：先 HTTPS，失败转 SSH | 手动 |

## 两个容易踩的点

**start-bot.sh 里的 `docker update --restart=always` 不能删。**
手动 `docker stop` 会把 restart 策略改成 `no`。不设回来的话，
Docker 或 WSL 重启后两个容器不会自己起来。2026-10-19 踩过这个坑。

**anchor.sh 判断反向 WS 健康不能只看 TCP 端口。**
`connect_ex(('astrbot', 6199)) == 0` 只能说明端口有监听，但 NapCat 的
WebSocket 握手仍可能超时（AstrBot 适配器没加载完时就是这样）。
旧版用 TCP 判定，AstrBot 一重启就误判断线，于是每 20 秒重启一次
napcat，把系统拖进「重启→不可用→再重启」的死循环。现在改读日志判定，
且连续 3 轮才重启。

## `do_push.sh` / `push_now.sh` 说明

这两个从 `/root/.gh_token` 读 token，**不把 token 写进文件**，
所以可以公开。但它们是针对 `zzyoxml/dafeiyu-deploy` 这个具体仓库的，
你 fork 之后要改仓库名。

实际推送推荐用 SSH Deploy Key（本项目用的就是这套），
这两个脚本是当时 PAT 权限出问题时的兜底方案。
