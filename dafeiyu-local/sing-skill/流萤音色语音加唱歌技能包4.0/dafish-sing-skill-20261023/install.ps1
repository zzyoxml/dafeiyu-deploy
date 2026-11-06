<#
  给 DSH + QQ 机器人装上「上网搜歌 + 唱歌 + 发语音」技能。

  设计目标：**不绑定某台机器、某个 qq-bridge 版本**。
  - 目录自动探测（也可用参数覆盖），不再写死 D:\软件\qq-bridge
  - 每一处补丁都做「结构定位 + 找不到就跳过并提示手工」的降级处理，不再因为版本差异直接失败
  - 语音发送工具名可配置（qq_send_voice / send_voice / upload_voice …），写进 mcp-sing.js 与角色卡
  - 没有 qq-bridge（只想要 MCP 工具）时也能装：只做「复制文件 + 注册 MCP + 角色卡」

  做的事：
    1. 把 mcp-sing.js / cover.py / rvc_cli / 模型 复制进机器人目录
    2. 在 DSH profile 的 cordis.patch.yml 注册 mcp-sing
    3. 若存在 qq-agent-presets，把 mcp__sing__ 加进工具白名单
    4. 若存在 bridge.js 的二代 toolMap，补 singCover 一行
    5. 若存在 setup-dsh.mjs 的 MANAGED_MCP_IDS，加 mcp-sing 防被删
    6. 往角色卡追加「唱歌」段落（工具名按 -VoiceTool 替换）

  用法：
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -QqBridgeRoot "D:\软件\qq-bridge"
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -VoiceTool send_voice -ProfileName desktop

  所有被改动的文件先备份为 *.bak-sing-skill-<时间>，可用 uninstall.ps1 回滚。
#>
param(
  [string]$QqBridgeRoot = '',
  [string]$DshProfile = '',
  [string]$ProfileName = '',
  [string]$NodeExe = '',
  [string]$RoleFile = '',
  [string]$VoiceTool = 'qq_send_voice',
  [switch]$SkipRole,
  [switch]$SkipModels,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$nl = [Environment]::NewLine
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $here 'payload'
$stamp = 'bak-sing-skill-' + (Get-Date -Format 'yyyyMMddHHmm')
$script:report = New-Object System.Collections.ArrayList

function Say($m) { Write-Host "  $m" }
function Step($m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }
function Note($status, $what, $detail = '') {
  [void]$script:report.Add([pscustomobject]@{ 状态 = $status; 项目 = $what; 说明 = $detail })
}
function BackUp($p) {
  if (-not (Test-Path $p)) { return }
  $bak = "$p.$stamp"
  if (-not (Test-Path $bak)) { Copy-Item $p $bak -Force; Say ("备份 -> " + (Split-Path $bak -Leaf)) }
}
function WriteText($p, $text) {
  if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
  [IO.File]::WriteAllText($p, $text, (New-Object System.Text.UTF8Encoding($false)))
}
function ReadText($p) { $t = Get-Content $p -Raw; if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) { $t = $t.Substring(1) }; return $t }

# ── 1. 环境探测 ─────────────────────────────────────────────
Step "1/6 探测环境"

if (-not $QqBridgeRoot) {
  $cands = @()
  if ($env:QQBRIDGE_ROOT) { $cands += $env:QQBRIDGE_ROOT }
  $cands += @(
    'D:\软件\qq-bridge',
    'D:\qq-bridge',
    'C:\qq-bridge',
    (Join-Path $env:USERPROFILE 'qq-bridge'),
    (Join-Path $env:USERPROFILE 'Documents\qq-bridge'),
    (Join-Path $here '..')
  )
  $hit = $cands | Where-Object { $_ -and (Test-Path (Join-Path $_ 'src\bridge.js')) } | Select-Object -First 1
  if ($hit) { $QqBridgeRoot = (Resolve-Path $hit).Path }
}

$hasBridge = $false
if ($QqBridgeRoot) {
  $QqBridgeRoot = (Resolve-Path $QqBridgeRoot -ErrorAction SilentlyContinue).Path
  if ($QqBridgeRoot) { $hasBridge = Test-Path (Join-Path $QqBridgeRoot 'src\bridge.js') }
}
if (-not $QqBridgeRoot) {
  throw "没能自动找到机器人目录（要含 src\bridge.js）。用 -QqBridgeRoot 指定安装位置。"
}
Say "机器人目录 = $QqBridgeRoot"
Say ("模式       = " + $(if ($hasBridge) { 'qq-bridge（会打桥接补丁）' } else { '通用（只有 MCP + 角色卡）' }))
Note '探测' '机器人目录' $QqBridgeRoot
if (-not $hasBridge) { Note '跳过' '桥接相关补丁' '目标目录没有 src\bridge.js' }

if (-not $NodeExe) {
  $nc = @(
    (Join-Path $env:USERPROFILE '.dsh\pet-node\node.exe'),
    (Join-Path $env:ProgramFiles 'nodejs\node.exe')
  )
  $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($cmd) { $nc += $cmd.Source }
  $NodeExe = ($nc | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1)
}
if (-not $NodeExe) { throw '找不到 node.exe，用 -NodeExe 指定' }
Say "node.exe   = $NodeExe"
Note '探测' 'node.exe' $NodeExe

if (-not $DshProfile) {
  $profRoot = Join-Path $env:USERPROFILE '.dsh\profiles'
  if ($ProfileName) {
    $p = Join-Path $profRoot $ProfileName
    if (Test-Path (Join-Path $p 'cordis.patch.yml')) { $DshProfile = (Resolve-Path $p).Path }
  }
  if (-not $DshProfile) {
    $all = Get-ChildItem $profRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { Test-Path (Join-Path $_.FullName 'cordis.patch.yml') }
    $hit2 = $all | Where-Object {
      $t = ReadText (Join-Path $_.FullName 'cordis.patch.yml')
      $t -match 'qq-bridge' -or $t -match 'mcp-'
    } | Select-Object -First 1
    if (-not $hit2) { $hit2 = $all | Select-Object -First 1 }
    if ($hit2) { $DshProfile = $hit2.FullName }
  }
  if (-not $DshProfile) { throw '没找到 DSH profile（~/.dsh/profiles/*/cordis.patch.yml），用 -DshProfile 或 -ProfileName 指定' }
}
$patchFile = Join-Path $DshProfile 'cordis.patch.yml'
if (-not (Test-Path $patchFile)) { throw "找不到 $patchFile" }
Say "DSH profile= $DshProfile"
Note '探测' 'DSH profile' $DshProfile
Say "语音工具名 = $VoiceTool"

# QQ 客户端路径检查：注入式加载器（NapCat 等）遇到含空格路径会报
#   Cannot find module 'D:\Program ...loadNapCat.js'
# 这里提前查出来，别等装完才发现。
$qqDirs = @()
foreach ($key in @('HKCU:\Software\Tencent\QQNT', 'HKLM:\SOFTWARE\Tencent\QQNT', 'HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT')) {
  $v = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
  if ($v) { foreach ($n in @('InstallDir', 'InstallPath', 'Path')) { if ($v.$n -and (Test-Path $v.$n)) { $qqDirs += $v.$n } } }
}
$qqDirs += @('C:\Program Files\Tencent\QQNT', 'D:\Program Files\Tencent\QQNT', (Join-Path $env:LOCALAPPDATA 'Programs\QQNT')) | Where-Object { Test-Path $_ }
$qqDir = ($qqDirs | Select-Object -Unique -First 1)
if ($qqDir) {
  Say "QQ 安装目录= $qqDir"
  if ($qqDir -match '\s') {
    Say "注意：QQ 路径含空格，注入式加载器（NapCat）可能起不来（Cannot find module '...\loadNapCat.js'）"
    Note '注意' 'QQ 路径含空格' "建议重装到无空格路径；本技能不依赖 QQ 目录，但机器人本身会受影响"
  } else {
    Note '探测' 'QQ 安装目录' $qqDir
  }
}

# 后端类型（只用于报告，不影响安装逻辑）
$backend = if ($hasBridge) { 'qq-bridge' } else { '通用（非 qq-bridge）' }
if (Get-Command napcat -ErrorAction SilentlyContinue) { $backend += ' + NapCat' }
Say "机器人后端 = $backend"
Note '探测' '机器人后端' $backend

# ── 2. 复制文件 ─────────────────────────────────────────────
Step "2/6 复制文件"
$relFiles = @('src\mcp-sing.js', 'sing\cover.py', 'sing\convert_model.py', 'sing\requirements.txt', 'sing\requirements-lock.txt')
foreach ($rel in $relFiles) {
  $src = Join-Path $payload $rel
  $dst = Join-Path $QqBridgeRoot $rel
  if (-not (Test-Path $src)) { continue }
  if ($DryRun) { Say "会复制 $rel"; continue }
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  BackUp $dst
  Copy-Item $src $dst -Force
  Say "复制 $rel"
}
# mcp-sing.js 里的默认语音工具名按安装参数改写（环境变量 SING_VOICE_TOOL 仍可覆盖）
$mcpSingJs = Join-Path $QqBridgeRoot 'src\mcp-sing.js'
if ((-not $DryRun) -and (Test-Path $mcpSingJs) -and $VoiceTool) {
  $t = ReadText $mcpSingJs
  $t2 = $t -replace "process\.env\.SING_VOICE_TOOL \|\| '[^']*'", "process.env.SING_VOICE_TOOL || '$VoiceTool'"
  if ($t2 -ne $t) { WriteText $mcpSingJs $t2; Say "mcp-sing.js 的默认语音工具名 -> $VoiceTool" }
}
if (-not $DryRun) { Note '完成' '复制 mcp-sing.js 等' $QqBridgeRoot }

$rvcSrc = Join-Path $payload 'sing\rvc_cli'
$rvcDst = Join-Path $QqBridgeRoot 'sing\rvc_cli'
if (Test-Path $rvcSrc) {
  if ($DryRun) { Say "会复制 rvc_cli（只有代码，不含模型）" }
  else {
    $n = 0
    Get-ChildItem $rvcSrc -Recurse -File | ForEach-Object {
      $rel = $_.FullName.Substring($rvcSrc.Length).TrimStart('\')
      $dst = Join-Path $rvcDst $rel
      New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
      Copy-Item $_.FullName $dst -Force
      $n++
    }
    Say "复制 rvc_cli：$n 个文件"
    Note '完成' '复制 rvc_cli' "$n 个文件"
  }
}

$modelsSrc = Join-Path $here 'models\sing'
if (Test-Path $modelsSrc) {
  if ($SkipModels) { Say "按参数跳过模型复制"; Note '跳过' '模型复制' '-SkipModels' }
  elseif ($DryRun) { Say "会复制 models\sing 下的模型（约 590 MB，含流萤音色模型）" }
  else {
    $mc = 0
    Get-ChildItem $modelsSrc -Recurse -File | ForEach-Object {
      $rel = $_.FullName.Substring($modelsSrc.Length).TrimStart('\')
      $dst = Join-Path (Join-Path $QqBridgeRoot 'sing') $rel
      New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
      if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst -Force; $mc++ }
    }
    Say "复制模型：$mc 个文件（已存在的跳过）"
    Note '完成' '复制模型' "$mc 个（已存在的跳过）"
  }
}

# ── 3. 注册 MCP ────────────────────────────────────────────
Step "3/6 注册 MCP 服务器（cordis.patch.yml）"
$patchText = ReadText $patchFile
if ($patchText -match 'mcp-sing') {
  Say "已注册过，跳过"; Note '跳过' 'cordis 注册' '已存在 mcp-sing'
} else {
  $block = $nl + "# === 唱歌技能 BEGIN（install.ps1 写入，可整段删除）===" + $nl
  $block += "- insert:" + $nl
  $block += "    - id: mcp-sing" + $nl
  $block += "      name: '@deepseek-ai/dsh-mcp-client'" + $nl
  $block += "      config:" + $nl
  $block += "        serverName: sing" + $nl
  $block += "        transport: stdio" + $nl
  $block += "        command: '$NodeExe'" + $nl
  $block += "        args:" + $nl
  $block += "          - '$mcpSingJs'" + $nl
  $block += "        toolCallTimeoutMs: 600000" + $nl
  $block += "# === 唱歌技能 END ===" + $nl
  if ($DryRun) { Say "会追加 mcp-sing 注册块"; Note '计划' 'cordis 注册' '追加 mcp-sing' }
  else {
    BackUp $patchFile
    Add-Content -Path $patchFile -Value $block -Encoding UTF8
    Say "已追加注册块"; Note '完成' 'cordis 注册' "$patchFile"
  }
}

# ── 4. 工具白名单 ──────────────────────────────────────────
Step "4/6 工具白名单"
$restrict = Join-Path $QqBridgeRoot 'plugins\qq-agent-presets\qq-tool-restrict.mjs'
if (-not (Test-Path $restrict)) {
  Say "没有 qq-agent-presets 守卫，跳过（非 qq-bridge 环境正常）"
  Note '跳过' '工具白名单' '无 qq-tool-restrict.mjs'
} else {
  $t = ReadText $restrict
  if ($t -match 'mcp__sing__') {
    Say "白名单已有 mcp__sing__，跳过"; Note '跳过' '工具白名单' '已存在'
  } else {
    $idx = $t.IndexOf('SAFE_PREFIXES')
    $open = -1
    if ($idx -ge 0) { $open = $t.IndexOf('[', $idx) }
    if ($open -lt 0) {
      Say "没找到 SAFE_PREFIXES 数组，跳过（请手工加 'mcp__sing__'）"
      Note '需手工' '工具白名单' '结构不匹配，手工加 mcp__sing__'
    } elseif ($DryRun) {
      Say "会把 mcp__sing__ 插入 SAFE_PREFIXES"; Note '计划' '工具白名单' '插入 mcp__sing__'
    } else {
      BackUp $restrict
      $ins = $nl + "  'mcp__sing__',"
      $t = $t.Substring(0, $open + 1) + $ins + $t.Substring($open + 1)
      WriteText $restrict $t
      Say "已加入 mcp__sing__"; Note '完成' '工具白名单' $restrict
    }
  }
}

# ── 5. 二代提示词 toolMap + setup-dsh ──────────────────────
Step "5/6 桥接侧补丁"
$bridgeJs = Join-Path $QqBridgeRoot 'src\bridge.js'
if (-not (Test-Path $bridgeJs)) {
  Say "没有 bridge.js，跳过 toolMap / MANAGED_MCP_IDS（通用模式）"
  Note '跳过' '桥接补丁' '无 bridge.js'
} else {
  $b = ReadText $bridgeJs
  if ($b -match 'singCover') {
    Say "toolMap 已有 singCover，跳过"; Note '跳过' 'toolMap' '已存在'
  } else {
    $anchor = $null
    foreach ($pat in @('(?m)^(?<indent>[ \t]*)waitMessages:', '(?m)^(?<indent>[ \t]*)sendImage:', '(?m)^(?<indent>[ \t]*)sendMessage:')) {
      $m = [regex]::Match($b, $pat)
      if ($m.Success) { $anchor = $m; break }
    }
    if (-not $anchor) {
      Say "toolMap 里找不到可用锚点，跳过（请手工补 singCover 一行）"
      Note '需手工' 'toolMap' '找不到锚点，手工补 singCover'
    } elseif ($DryRun) {
      Say "会补 singCover 一行"; Note '计划' 'toolMap' '补 singCover'
    } else {
      BackUp $bridgeJs
      $indent = $anchor.Groups['indent'].Value
      $line = $indent + "singCover: 'sing_cover / sing_search（唱一段歌，最多 4 分钟）'," + $nl
      $pos = $anchor.Index
      $b = $b.Substring(0, $pos) + $line + $b.Substring($pos)
      WriteText $bridgeJs $b
      Say "已补 singCover"; Note '完成' 'toolMap' $bridgeJs
    }
  }

  $setup = Join-Path $QqBridgeRoot 'scripts\setup-dsh.mjs'
  if (-not (Test-Path $setup)) {
    Say "没有 setup-dsh.mjs，跳过"; Note '跳过' 'setup-dsh' '文件不存在'
  } else {
    $s = ReadText $setup
    if ($s -match 'mcp-sing') {
      Say "setup-dsh.mjs 已含 mcp-sing，跳过"; Note '跳过' 'setup-dsh' '已存在'
    } else {
      $i2 = $s.IndexOf('MANAGED_MCP_IDS')
      $o2 = -1
      if ($i2 -ge 0) { $o2 = $s.IndexOf('[', $i2) }
      if ($o2 -lt 0) {
        Say "setup-dsh.mjs 没有 MANAGED_MCP_IDS，跳过"
        Note '跳过' 'setup-dsh' '无 MANAGED_MCP_IDS'
      } elseif ($DryRun) {
        Say "会把 mcp-sing 加进 MANAGED_MCP_IDS"; Note '计划' 'setup-dsh' '加 mcp-sing'
      } else {
        BackUp $setup
        $s = $s.Substring(0, $o2 + 1) + $nl + "  'mcp-sing'," + $s.Substring($o2 + 1)
        WriteText $setup $s
        Say "已加进 MANAGED_MCP_IDS"; Note '完成' 'setup-dsh' $setup
      }
    }
  }
}

# ── 6. 角色卡 ──────────────────────────────────────────────
Step "6/6 角色卡"
if ($SkipRole) {
  Say "按参数跳过"; Note '跳过' '角色卡' '-SkipRole'
} else {
  if (-not $RoleFile) {
    $rolesDir = Join-Path $QqBridgeRoot 'roles'
    if (Test-Path $rolesDir) {
      $cands = Get-ChildItem $rolesDir -Filter *.md |
        Where-Object { $_.Name -notmatch '^(?i)readme' -and $_.Name -notmatch '\.bak' }
      if ($cands.Count -eq 1) { $RoleFile = $cands[0].FullName }
      elseif ($cands.Count -gt 1) {
        $RoleFile = ($cands | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        Say ("角色卡有 " + $cands.Count + " 个，按最近修改选了 " + (Split-Path $RoleFile -Leaf) + "（可用 -RoleFile 指定）")
      }
    }
  }
  if (-not $RoleFile -or -not (Test-Path $RoleFile)) {
    Say "没找到角色卡，跳过（可用 -RoleFile 指定）"; Note '跳过' '角色卡' '未找到角色文件'
  } else {
    $r = ReadText $RoleFile
    if ($r -match '唱歌技能 BEGIN') {
      Say "角色卡已有唱歌段落，跳过"; Note '跳过' '角色卡' '已存在段落'
    } elseif ($DryRun) {
      Say ("会往 " + (Split-Path $RoleFile -Leaf) + " 追加唱歌段落（工具名 $VoiceTool）")
      Note '计划' '角色卡' (Split-Path $RoleFile -Leaf)
    } else {
      BackUp $RoleFile
      $section = ReadText (Join-Path $payload 'roles\sing-skill-section.md')
      $section = $section.Replace('{{VOICE_TOOL}}', $VoiceTool)
      Add-Content -Path $RoleFile -Value ($nl + $section) -Encoding UTF8
      Say "已追加唱歌段落"; Note '完成' '角色卡' (Split-Path $RoleFile -Leaf)
    }
  }
}

# ── 汇总 ──────────────────────────────────────────────────
Write-Host ""
Write-Host "== 结果汇总" -ForegroundColor Cyan
$script:report | Format-Table -AutoSize | Out-String | Write-Host
$manual = @($script:report | Where-Object { $_.状态 -eq '需手工' })
if ($manual.Count -gt 0) {
  Write-Host "有 $($manual.Count) 处需要手工处理（见上表）" -ForegroundColor Yellow
}

if ($DryRun) {
  Write-Host ""
  Write-Host "DryRun 结束：以上是计划，没有写任何文件。" -ForegroundColor Yellow
  exit 0
}

Write-Host ""
Write-Host "补丁部分完成。还需要手工做三件事：" -ForegroundColor Green
Write-Host "  1) 装 Python 依赖（在 $QqBridgeRoot\sing 下）："
Write-Host "       python -m venv venv"
Write-Host "       venv\Scripts\python -m pip install -r requirements.txt"
Write-Host "  2) 确认模型文件在 $QqBridgeRoot\sing\model（liuying.pth / rmvpe.pt / contentvec）"
Write-Host "  3) 确认 yt-dlp / ffmpeg 可用（PATH 或环境变量 DSH_YTDLP / DSH_FFMPEG），然后重启 DSH"
Write-Host ""
Write-Host "装完可以跑： powershell -ExecutionPolicy Bypass -File .\verify.ps1 -QqBridgeRoot `"$QqBridgeRoot`"" -ForegroundColor DarkGray
