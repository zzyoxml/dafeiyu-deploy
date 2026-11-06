<#
  唱歌技能自检：装完（或换机器后）跑一遍，看还差什么。
  用法：
    powershell -ExecutionPolicy Bypass -File .\verify.ps1
    powershell -ExecutionPolicy Bypass -File .\verify.ps1 -QqBridgeRoot "D:\软件\qq-bridge"
  只读，不改任何文件。
#>
param(
  [string]$QqBridgeRoot = '',
  [string]$DshProfile = '',
  [string]$ProfileName = '',
  [string]$VoiceTool = 'qq_send_voice'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$rows = New-Object System.Collections.ArrayList
function Add-Row($status, $item, $detail) { [void]$rows.Add([pscustomobject]@{ 结果 = $status; 检查项 = $item; 说明 = $detail }) }
function ReadText($p) { $t = Get-Content $p -Raw; if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) { $t = $t.Substring(1) }; return $t }

# 机器人目录
if (-not $QqBridgeRoot) {
  $cands = @()
  if ($env:QQBRIDGE_ROOT) { $cands += $env:QQBRIDGE_ROOT }
  $cands += @('D:\软件\qq-bridge', 'D:\qq-bridge', 'C:\qq-bridge', (Join-Path $env:USERPROFILE 'qq-bridge'))
  $hit = $cands | Where-Object { Test-Path (Join-Path $_ 'src\bridge.js') } | Select-Object -First 1
  if ($hit) { $QqBridgeRoot = (Resolve-Path $hit).Path }
}
if (-not $QqBridgeRoot -or -not (Test-Path $QqBridgeRoot)) {
  Add-Row 'FAIL' '机器人目录' '没找到（用 -QqBridgeRoot 指定）'
  $rows | Format-Table -AutoSize | Out-String | Write-Host
  exit 1
}
Add-Row 'OK' '机器人目录' $QqBridgeRoot

# 文件
$mcp = Join-Path $QqBridgeRoot 'src\mcp-sing.js'
if (Test-Path $mcp) {
  $t = ReadText $mcp
  $tool = if ($t -match "SING_VOICE_TOOL \|\| '([^']*)'") { $Matches[1] } else { $null }
  if ($tool) {
    Add-Row 'OK' 'src\mcp-sing.js' "存在；默认语音工具=$tool"
    if ($tool -ne $VoiceTool) { Add-Row 'WARN' '语音工具名' "文件里是 $tool，期望 $VoiceTool（可用 -VoiceTool 重装）" }
  } else {
    Add-Row 'INFO' 'src\mcp-sing.js' '旧版文件（未含 SING_VOICE_TOOL，按内置 qq_send_voice 行为；重装可升级）'
  }
} else { Add-Row 'FAIL' 'src\mcp-sing.js' '缺失' }

foreach ($rel in @('sing\cover.py', 'sing\rvc_cli', 'sing\model\liuying.pth', 'sing\model\rmvpe.pt', 'sing\rvc\models\embedders\contentvec')) {
  $p = Join-Path $QqBridgeRoot $rel
  if (Test-Path $p) { Add-Row 'OK' $rel '' } else { Add-Row 'WARN' $rel '缺失（AI 翻唱会点名缺它）' }
}

# Python 与依赖
$py = Join-Path $QqBridgeRoot 'sing\venv\Scripts\python.exe'
if (Test-Path $py) {
  Add-Row 'OK' 'sing\venv' $py
  try {
    $v = & $py -c "import torch,sys;print(torch.__version__, torch.cuda.is_available())" 2>&1
    Add-Row 'OK' 'torch' ($v -join ' ')
  } catch { Add-Row 'WARN' 'torch' '导入失败（mode=ai 不可用）' }
} else { Add-Row 'WARN' 'sing\venv' '未创建（mode=ai 不可用；mode=original 不需要）' }

# 外部命令
function Find-Exe($envFile, $rel, $bare) {
  $fromEnv = if ($envFile) { [Environment]::GetEnvironmentVariable($envFile) } else { '' }
  if ($fromEnv -and (Test-Path $fromEnv)) { return $fromEnv }
  $c = Join-Path $QqBridgeRoot $rel
  if (Test-Path $c) { return $c }
  $cmd = Get-Command $bare -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}
$yt = Find-Exe 'DSH_YTDLP' 'video\venv\Scripts\yt-dlp.exe' 'yt-dlp.exe'
$ff = Find-Exe 'DSH_FFMPEG' 'video\bin\ffmpeg.exe' 'ffmpeg.exe'
Add-Row $(if ($yt) { 'OK' } else { 'FAIL' }) 'yt-dlp' $(if ($yt) { $yt } else { 'PATH 上找不到' })
Add-Row $(if ($ff) { 'OK' } else { 'FAIL' }) 'ffmpeg' $(if ($ff) { $ff } else { 'PATH 上找不到' })

# 注册与补丁
if (-not $DshProfile) {
  $profRoot = Join-Path $env:USERPROFILE '.dsh\profiles'
  if ($ProfileName) { $p = Join-Path $profRoot $ProfileName; if (Test-Path (Join-Path $p 'cordis.patch.yml')) { $DshProfile = $p } }
  if (-not $DshProfile) {
    $all = Get-ChildItem $profRoot -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'cordis.patch.yml') }
    $hit2 = $all | Where-Object { (ReadText (Join-Path $_.FullName 'cordis.patch.yml')) -match 'mcp-sing' } | Select-Object -First 1
    if ($hit2) { $DshProfile = $hit2.FullName }
  }
}
if ($DshProfile) {
  $pt = ReadText (Join-Path $DshProfile 'cordis.patch.yml')
  Add-Row $(if ($pt -match 'mcp-sing') { 'OK' } else { 'FAIL' }) 'cordis.patch.yml' $(if ($pt -match 'mcp-sing') { '已注册 mcp-sing' } else { '没有 mcp-sing 注册块' })
} else { Add-Row 'WARN' 'cordis.patch.yml' '找不到 DSH profile' }

$restrict = Join-Path $QqBridgeRoot 'plugins\qq-agent-presets\qq-tool-restrict.mjs'
if (Test-Path $restrict) {
  $rt = ReadText $restrict
  Add-Row $(if ($rt -match 'mcp__sing__') { 'OK' } else { 'FAIL' }) '工具白名单' $(if ($rt -match 'mcp__sing__') { '已含 mcp__sing__' } else { '缺少 mcp__sing__' })
} else { Add-Row 'WARN' '工具白名单' '没有 qq-agent-presets（非 qq-bridge 环境可忽略）' }

$bridge = Join-Path $QqBridgeRoot 'src\bridge.js'
if (Test-Path $bridge) {
  $bt = ReadText $bridge
  Add-Row $(if ($bt -match 'singCover') { 'OK' } else { 'WARN' }) 'toolMap' $(if ($bt -match 'singCover') { '已补 singCover' } else { '没补（只影响提示词里是否主动提唱歌）' })
} else { Add-Row 'WARN' 'bridge.js' '不存在（通用模式）' }

Write-Host ""
Write-Host "== 自检结果" -ForegroundColor Cyan
$rows | Format-Table -AutoSize | Out-String | Write-Host
$fail = @($rows | Where-Object { $_.结果 -eq 'FAIL' }).Count
$warn = @($rows | Where-Object { $_.结果 -eq 'WARN' }).Count
Write-Host ("FAIL: $fail   WARN: $warn") -ForegroundColor $(if ($fail -gt 0) { 'Red' } elseif ($warn -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "提示：改完 MCP 相关配置要重启 DSH 才会加载新的工具列表。"
if ($fail -gt 0) { exit 1 }
