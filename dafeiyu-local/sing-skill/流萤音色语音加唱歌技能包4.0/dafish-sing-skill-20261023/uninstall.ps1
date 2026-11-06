<#
  回滚 install.ps1 的改动（备份形如 *.bak-sing-skill-<时间>）。
  只回滚「注册与补丁」，不会删 sing 下的模型、venv 和代码。
  用法： powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
         powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -QqBridgeRoot "D:\软件\qq-bridge"
#>
param(
  [string]$QqBridgeRoot = '',
  [string]$DshProfile = '',
  [string]$ProfileName = ''
)

$ErrorActionPreference = 'Stop'

function Restore($p) {
  if (-not (Test-Path $p)) { Write-Host ("不存在：" + $p); return }
  $dir = Split-Path $p -Parent
  $leaf = Split-Path $p -Leaf
  $bak = Get-ChildItem $dir -Filter ($leaf + '.bak-sing-skill-*') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($bak) { Copy-Item $bak.FullName $p -Force; Write-Host ("已回滚 " + $leaf + "（来自 " + $bak.Name + "）") }
  else { Write-Host ("没有备份可回滚：" + $leaf) }
}

# 自动找机器人目录（与 install.ps1 同一套规则）
if (-not $QqBridgeRoot) {
  $cands = @()
  if ($env:QQBRIDGE_ROOT) { $cands += $env:QQBRIDGE_ROOT }
  $cands += @(
    'D:\软件\qq-bridge', 'D:\qq-bridge', 'C:\qq-bridge',
    (Join-Path $env:USERPROFILE 'qq-bridge'),
    (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..')
  )
  $hit = $cands | Where-Object { $_ -and (Test-Path (Join-Path $_ 'src\bridge.js')) } | Select-Object -First 1
  if ($hit) { $QqBridgeRoot = (Resolve-Path $hit).Path }
}

if (-not $DshProfile) {
  $profRoot = Join-Path $env:USERPROFILE '.dsh\profiles'
  if ($ProfileName) {
    $p = Join-Path $profRoot $ProfileName
    if (Test-Path (Join-Path $p 'cordis.patch.yml')) { $DshProfile = (Resolve-Path $p).Path }
  }
  if (-not $DshProfile -and (Test-Path $profRoot)) {
    $roots = Get-ChildItem $profRoot -Directory -ErrorAction SilentlyContinue
    $hitP = $roots | Where-Object { Test-Path (Join-Path $_.FullName 'cordis.patch.yml') } |
      Where-Object { (Get-Content (Join-Path $_.FullName 'cordis.patch.yml') -Raw) -match 'mcp-sing' } |
      Select-Object -First 1
    if ($hitP) { $DshProfile = $hitP.FullName }
  }
}
if ($DshProfile) { Restore (Join-Path $DshProfile 'cordis.patch.yml') }
else { Write-Host "没找到注册过 mcp-sing 的 profile，跳过 cordis 回滚" }

if ($QqBridgeRoot) {
  Restore (Join-Path $QqBridgeRoot 'plugins\qq-agent-presets\qq-tool-restrict.mjs')
  Restore (Join-Path $QqBridgeRoot 'src\bridge.js')
  Restore (Join-Path $QqBridgeRoot 'scripts\setup-dsh.mjs')
  Restore (Join-Path $QqBridgeRoot 'src\mcp-sing.js')
} else {
  Write-Host "没找到机器人目录，跳过桥接侧回滚（可用 -QqBridgeRoot 指定）"
}

Write-Host ""
Write-Host "回滚完成。角色卡里的「唱歌技能 BEGIN/END」段落请手工删掉。" -ForegroundColor Yellow
Write-Host "记得重启 DSH 让 MCP 列表刷新。" -ForegroundColor Yellow
