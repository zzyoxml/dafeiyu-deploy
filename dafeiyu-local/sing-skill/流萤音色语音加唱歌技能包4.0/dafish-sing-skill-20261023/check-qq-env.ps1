<#
  QQ 机器人环境自检：装唱歌技能之前先跑这个，看清楚这台机器是什么结构、哪里会踩坑。
  只读，不改任何文件。

  用法：
    powershell -ExecutionPolicy Bypass -File .\check-qq-env.ps1
    powershell -ExecutionPolicy Bypass -File .\check-qq-env.ps1 -QqBridgeRoot "E:\bots\qq-bridge"
#>
param(
  [string]$QqBridgeRoot = ''
)

$ErrorActionPreference = 'SilentlyContinue'
$rows = New-Object System.Collections.ArrayList
$tips = New-Object System.Collections.ArrayList
function Add-Row($status, $item, $detail) { [void]$rows.Add([pscustomobject]@{ 结果 = $status; 项目 = $item; 说明 = $detail }) }
function Tip($t) { [void]$tips.Add($t) }
function Test-Port($p) {
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $iar = $c.BeginConnect('127.0.0.1', $p, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(400)
    $c.Close()
    return $ok
  } catch { return $false }
}

Write-Host ""
Write-Host "== QQ 机器人环境自检" -ForegroundColor Cyan

# 1) Windows / PowerShell
Add-Row 'OK' '操作系统' ([Environment]::OSVersion.VersionString)
Add-Row 'OK' 'PowerShell' $PSVersionTable.PSVersion.ToString()

# 2) QQ NT 安装位置（含注册表与常见目录）
$qqDirs = New-Object System.Collections.ArrayList
foreach ($key in @('HKCU:\Software\Tencent\QQNT', 'HKLM:\SOFTWARE\Tencent\QQNT', 'HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT')) {
  $v = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue)
  if ($v) {
    foreach ($name in @('InstallDir', 'InstallPath', 'Path')) {
      if ($v.$name -and (Test-Path $v.$name)) { [void]$qqDirs.Add($v.$name) }
    }
  }
}
foreach ($p in @(
    'C:\Program Files\Tencent\QQNT', 'D:\Program Files\Tencent\QQNT',
    (Join-Path $env:LOCALAPPDATA 'Programs\QQNT'), 'C:\Tencent\QQNT', 'D:\Tencent\QQNT'
  )) { if (Test-Path $p) { [void]$qqDirs.Add($p) } }

if ($qqDirs.Count -eq 0) {
  Add-Row 'WARN' 'QQ NT 安装目录' '没探测到（可能没装 QQ，或装在非常规路径）'
} else {
  $qq = ($qqDirs | Select-Object -Unique -First 1)
  Add-Row 'OK' 'QQ NT 安装目录' $qq
  if ($qq -match '\s') {
    Add-Row 'FAIL' 'QQ 路径含空格' $qq
    Tip "QQ 装在含空格的路径（$qq）。NapCat 等注入式加载器经常把命令行按空格切开，报 `"Cannot find module 'D:\Program ...loadNapCat.js'`"。"
    Tip "处理：把 QQ 重装到无空格路径（如 D:\QQNT），或换用最新版加载器（新版已处理引号）。"
  } else {
    Add-Row 'OK' 'QQ 路径空格' '无空格'
  }
  # 版本目录
  $verDir = Join-Path $qq 'versions'
  if (Test-Path $verDir) {
    $vers = Get-ChildItem $verDir -Directory | Select-Object -ExpandProperty Name
    Add-Row 'OK' 'QQ 版本目录' (($vers | Select-Object -First 5) -join ', ')
  }
}

# 3) 机器人后端
function Find-BridgeRoot {
  $c = @()
  if ($env:QQBRIDGE_ROOT) { $c += $env:QQBRIDGE_ROOT }
  $c += @('D:\软件\qq-bridge', 'D:\qq-bridge', 'C:\qq-bridge', (Join-Path $env:USERPROFILE 'qq-bridge'),
    (Join-Path (Split-Path -Parent $MyInvocation.ScriptName) '..'))
  return ($c | Where-Object { $_ -and (Test-Path (Join-Path $_ 'src\bridge.js')) } | Select-Object -First 1)
}

$backends = @()
if (-not $QqBridgeRoot) { $QqBridgeRoot = Find-BridgeRoot }
if ($QqBridgeRoot -and (Test-Path (Join-Path $QqBridgeRoot 'src\bridge.js'))) {
  $backends += 'qq-bridge'
  Add-Row 'OK' 'qq-bridge' $QqBridgeRoot
  if (Test-Path (Join-Path $QqBridgeRoot 'plugins\qq-agent-presets\qq-tool-restrict.mjs')) {
    Add-Row 'OK' 'qq-agent-presets 守卫' '存在（装技能会补 mcp__sing__ 白名单）'
  } else {
    Add-Row 'WARN' 'qq-agent-presets 守卫' '不存在（没有白名单机制，跳过即可）'
  }
} else {
  Add-Row 'WARN' 'qq-bridge' '没找到 src\bridge.js'
}

# NapCat：找 loadNapCat.js / onebot11 配置
$napcatHits = @()
foreach ($base in @($qqDirs | Select-Object -Unique)) {
  $appDir = Join-Path $base 'resources\app'
  if (Test-Path $appDir) {
    $napcatHits += Get-ChildItem $appDir -Filter '*NapCat*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
  }
}
if (Test-Path (Join-Path $env:USERPROFILE 'Napcat')) { $napcatHits += (Join-Path $env:USERPROFILE 'Napcat') }
$ncCmd = Get-Command napcat -ErrorAction SilentlyContinue
if ($ncCmd) { $napcatHits += $ncCmd.Source }
if ($napcatHits.Count -gt 0) {
  $backends += 'napcat'
  Add-Row 'OK' 'NapCat' (($napcatHits | Select-Object -First 2) -join ' | ')
  Add-Row 'INFO' 'NapCat 适配' '技能包只依赖 OneBot 的「发语音」能力，NapCat 可用；桥接类补丁会自动跳过'
  Tip 'NapCat 用户：安装时加 -SkipRole 之外的桥接补丁会自动跳过；角色卡段落请手工贴，并把 {{VOICE_TOOL}} 换成你实际可用的发语音工具名。'
} else {
  Add-Row 'WARN' 'NapCat' '没发现（没装可忽略）'
}

# Lagrange / NoneBot
foreach ($exe in @('Lagrange.OneBot.exe', 'nb.exe', 'bot.py')) {
  $cmd = Get-Command $exe -ErrorAction SilentlyContinue
  if ($cmd) { Add-Row 'OK' $exe $cmd.Source; $backends += $exe }
}
if ($backends.Count -eq 0) { Add-Row 'WARN' '机器人后端' '一个都没识别到（先确认机器人能正常收发 QQ 消息）' }
else { Add-Row 'OK' '识别到的后端' (($backends | Select-Object -Unique) -join ', ') }

# 4) OneBot 端口
$ports = @(3000, 3001, 8080, 5700, 3100)
$open = @()
foreach ($p in $ports) { if (Test-Port $p) { $open += $p } }
if ($open.Count -gt 0) { Add-Row 'OK' '本机监听端口' (($open | ForEach-Object { ":$($_)" }) -join ' ') }
else { Add-Row 'WARN' '本机监听端口' '3000/3001/8080/5700/3100 都没开（机器人可能没启动）' }
if ($open -contains 3000 -and $open -contains 3001) {
  Add-Row 'INFO' '端口占用' '3000+3001 同时在线：通常是 OneBot 的 HTTP + WS（qq-bridge / SnowLuma / NapCat 都可能是）'
}

# 5) 运行依赖
$node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
Add-Row $(if ($node) { 'OK' } else { 'FAIL' }) 'node.exe' $(if ($node) { $node } else { 'PATH 上没有' })
$py = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
Add-Row $(if ($py) { 'OK' } else { 'WARN' }) 'python.exe' $(if ($py) { $py } else { 'PATH 上没有（mode=ai 需要）' })
function Resolve-Tool($envName, $relPaths, $bare) {
  $fromEnv = [Environment]::GetEnvironmentVariable($envName)
  if ($fromEnv -and (Test-Path $fromEnv)) { return $fromEnv }
  foreach ($rel in $relPaths) {
    if ($QqBridgeRoot) {
      $c = Join-Path $QqBridgeRoot $rel
      if (Test-Path $c) { return $c }
    }
  }
  $cmd = Get-Command $bare -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}
$ff = Resolve-Tool 'DSH_FFMPEG' @('video\bin\ffmpeg.exe', 'video\ffmpeg.exe', 'tools\ffmpeg.exe') 'ffmpeg.exe'
Add-Row $(if ($ff) { 'OK' } else { 'WARN' }) 'ffmpeg.exe' $(if ($ff) { $ff } else { '没找到（截片段必需；可设 DSH_FFMPEG）' })
$yt = Resolve-Tool 'DSH_YTDLP' @('video\venv\Scripts\yt-dlp.exe', 'video\bin\yt-dlp.exe', 'tools\yt-dlp.exe') 'yt-dlp.exe'
Add-Row $(if ($yt) { 'OK' } else { 'WARN' }) 'yt-dlp.exe' $(if ($yt) { $yt } else { '没找到（搜歌必需；可设 DSH_YTDLP）' })

# 6) DSH profile
$profRoot = Join-Path $env:USERPROFILE '.dsh\profiles'
$profiles = @()
if (Test-Path $profRoot) {
  $profiles = Get-ChildItem $profRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'cordis.patch.yml') } | Select-Object -ExpandProperty Name
}
Add-Row $(if ($profiles.Count -gt 0) { 'OK' } else { 'WARN' }) 'DSH profile' $(if ($profiles.Count -gt 0) { $profiles -join ', ' } else { '没找到 ~/.dsh/profiles/*/cordis.patch.yml' })

# 输出
Write-Host ""
$rows | Format-Table -AutoSize | Out-String -Width 160 | Write-Host

if ($tips.Count -gt 0) {
  Write-Host "== 建议" -ForegroundColor Yellow
  $i = 1
  foreach ($t in $tips) { Write-Host ("  $i. $t"); $i++ }
  Write-Host ""
}

$fails = @($rows | Where-Object { $_.结果 -eq 'FAIL' }).Count
if ($fails -gt 0) {
  Write-Host "有 $fails 项 FAIL，先把它们解决再装技能。" -ForegroundColor Red
  exit 1
}
Write-Host "环境检查通过，可以继续跑 install.ps1（建议先 -DryRun）。" -ForegroundColor Green
