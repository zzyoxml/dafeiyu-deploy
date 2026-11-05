# win/ —— Windows 侧脚本

放在 `D:\xml\dafeiyu\`。改路径的话三个 `.bat` 里的绝对路径都要跟着改。

## 日常用的三个

| 文件 | 作用 |
|---|---|
| `start.bat` | 启动。先检查 WSL 可用，再调 `/root/start-bot.sh`，最后起守护 |
| `stop.bat` | 停止。先杀守护（`stop-guard.ps1`），再调 `/root/stop-bot.sh` |
| `status.bat` | 状态。调 `/root/status-bot.sh` |

## 辅助

| 文件 | 作用 |
|---|---|
| `stop-guard.ps1` | 精确杀掉守护进程（见下方 Bug 2） |
| `guard.sh` | Windows 侧守护：读心跳文件，失联才干预 WSL |
| `guard-autostart.vbs` | 无窗口启动 `guard.sh`，注册表 Run 项指向它 |
| `keepalive.sh` | 手动巡检 |
| `run.sh` | 旧版启动脚本，保留参考 |
| `fix-wsl-run.bat` | WSL 被模拟器关掉时的修复（需管理员，之后要重启） |

## ⚠ 三个 `.bat` 必须保持纯 ASCII

`.bat` 里写中文注释，PowerShell 用 UTF-8 写入而 cmd 按 CP936 读取，
多字节字符会把整行拆坏，`REM` 注释变成多条命令执行，脚本直接崩。
实测过：加了中文注释后 `start.bat` 输出了 20 多条
`'xxx' is not recognized as an internal or external command`。

校验方法：

```powershell
$b = [System.IO.File]::ReadAllBytes("start.bat")
($b | Where-Object { $_ -gt 127 }).Count   # 必须是 0
```

需要中文说明就写在 `README.md` 里，不要写进 `.bat`。

## 修过的两个 bug

**Bug 1：stop.bat 会杀掉自己**

```bat
title DaFeiYu QQ Bot - Stop
taskkill /F /FI "WINDOWTITLE eq DaFeiYu*"
```

守护进程全无窗口（VBS + bash），没有那个标题的窗口可杀；
但过滤器会匹配到 `stop.bat` 自己的窗口，脚本执行到一半自我终止。
所以以前双击 stop.bat 是「一闪而逝」。已删掉该行。

**Bug 2：wmic 已从 Win11 移除**

原版用 `wmic process where ...` 查守护进程。Win11 24H2+ 删掉了
`wmic.exe`，两条命令静默失败（errorlevel 非 0），守护进程实际一个
都没被杀掉，脚本却打印 `no wscript guard found`。

实测：报告「没有守护进程」时，系统里有 3 个 `bash.exe` 在跑
`guard.sh`。改用 `stop-guard.ps1` + `Get-CimInstance` 精确匹配
CommandLine，实测成功杀掉。

## Theseus 式的提醒

`start.bat` / `stop.bat` 都加了 WSL 可用性前置检查。WSL 起不来时
会直接打印：

```
*** WSL CANNOT START ***
VirtualMachinePlatform or Hyper-V is disabled.
Fix: run fix-wsl-run.bat as Administrator, then reboot.
```

在此之前，这种情况只是静默闪退，看不出原因。
