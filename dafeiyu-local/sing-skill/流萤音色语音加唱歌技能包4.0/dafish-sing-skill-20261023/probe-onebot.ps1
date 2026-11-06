<#
  OneBot 探针：验证 HTTP 通道、账号在线、能不能发文本 / 发语音。
  只读为主；只有你显式给了 -UserId / -GroupId 才会真的发消息。

  用法：
    powershell -ExecutionPolicy Bypass -File .\probe-onebot.ps1
    powershell -ExecutionPolicy Bypass -File .\probe-onebot.ps1 -HttpUrl "http://127.0.0.1:3000" -Token "xxx"
    powershell -ExecutionPolicy Bypass -File .\probe-onebot.ps1 -Token "xxx" -UserId 10001
    powershell -ExecutionPolicy Bypass -File .\probe-onebot.ps1 -Token "xxx" -UserId 10001 -VoiceFile "D:\a\b.mp3"
#>
param(
  [string]$HttpUrl = 'http://127.0.0.1:3000',
  [string]$Token = '',
  [long]$UserId = 0,
  [long]$GroupId = 0,
  [string]$Text = '',
  [string]$VoiceFile = '',
  [int]$TimeoutSec = 20
)

$ErrorActionPreference = 'Stop'
$rows = New-Object System.Collections.ArrayList
function Add-Row($status, $item, $detail) { [void]$rows.Add([pscustomobject]@{ 结果 = $status; 项目 = $item; 说明 = $detail }) }

function Invoke-OneBot($action, $params) {
  $body = @{ action = $action; params = $params } | ConvertTo-Json -Depth 8 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  $headers = @{}
  if ($Token) { $headers['Authorization'] = "Bearer $Token" }
  $url = $HttpUrl.TrimEnd('/') + '/'
  try {
    $resp = Invoke-WebRequest -Uri $url -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' `
      -Body $bytes -TimeoutSec $TimeoutSec -UseBasicParsing
    $json = $null
    try { $json = $resp.Content | ConvertFrom-Json } catch {}
    return [pscustomobject]@{ http = [int]$resp.StatusCode; json = $json; raw = $resp.Content }
  } catch {
    $code = 0; $text = $_.Exception.Message
    if ($_.Exception.Response) {
      $code = [int]$_.Exception.Response.StatusCode
      try { $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream()); $text = $sr.ReadToEnd() } catch {}
    }
    return [pscustomobject]@{ http = $code; json = $null; raw = $text }
  }
}

function Show($r) {
  if (-not $r) { return '(空)' }
  if ($r.json) {
    $st = $r.json.status; $rc = $r.json.retcode; $wd = $r.json.wording
    return "status=$st retcode=$rc wording=$wd"
  }
  return ("HTTP " + $r.http + " " + ($r.raw -replace '\s+', ' ').Substring(0, [Math]::Min(160, ($r.raw -replace '\s+', ' ').Length)))
}

Write-Host ""
Write-Host "== OneBot 探针  $HttpUrl" -ForegroundColor Cyan

# 1) 登录信息
$login = Invoke-OneBot 'get_login_info' @{}
if ($login.json -and $login.json.status -eq 'ok' -and $login.json.data) {
  Add-Row 'OK' 'get_login_info' ("user_id=" + $login.json.data.user_id + " nickname=" + $login.json.data.nickname)
  $uin = $login.json.data.user_id
} else {
  Add-Row 'FAIL' 'get_login_info' (Show $login)
  $uin = $null
}

# 2) 版本
$ver = Invoke-OneBot 'get_version_info' @{}
if (-not ($ver.json -and $ver.json.status -eq 'ok')) { $ver = Invoke-OneBot 'get_version' @{} }
if ($ver.json -and $ver.json.status -eq 'ok' -and $ver.json.data) {
  $d = $ver.json.data
  Add-Row 'OK' '版本' (($d | ConvertTo-Json -Compress))
} else {
  Add-Row 'INFO' '版本' (Show $ver)
}

# 3) 在线状态
$st = Invoke-OneBot 'get_status' @{}
if ($st.json -and $st.json.status -eq 'ok' -and $st.json.data) {
  Add-Row 'OK' 'get_status' (($st.json.data | ConvertTo-Json -Compress))
} else {
  Add-Row 'INFO' 'get_status' (Show $st)
}

# 4) 可选：发文本
if ($UserId -gt 0 -or $GroupId -gt 0) {
  $target = if ($GroupId -gt 0) { 'group' } else { 'private' }
  $id = if ($GroupId -gt 0) { $GroupId } else { $UserId }
  $msg = if ($Text) { $Text } else { '（唱歌技能包：连接测试）' }
  $action = if ($target -eq 'group') { 'send_group_msg' } else { 'send_private_msg' }
  $params = if ($target -eq 'group') { @{ group_id = $id; message = @(@{ type = 'text'; data = @{ text = $msg } }) } }
            else { @{ user_id = $id; message = @(@{ type = 'text'; data = @{ text = $msg } }) } }
  $r = Invoke-OneBot $action $params
  if ($r.json -and $r.json.status -eq 'ok') { Add-Row 'OK' '发文本' ("message_id=" + $r.json.data.message_id) }
  else { Add-Row 'FAIL' '发文本' (Show $r) }
}

# 5) 可选：发语音（先 file://，失败再 base64）
if ($VoiceFile) {
  if (-not (Test-Path $VoiceFile)) {
    Add-Row 'FAIL' '发语音' "找不到文件：$VoiceFile"
  } else {
    $full = (Resolve-Path $VoiceFile).Path
    $target = if ($GroupId -gt 0) { 'group' } else { 'private' }
    $id = if ($GroupId -gt 0) { $GroupId } else { $UserId }
    if ($id -le 0) { Add-Row 'FAIL' '发语音' '要先给 -UserId 或 -GroupId' }
    else {
      $action = if ($target -eq 'group') { 'send_group_msg' } else { 'send_private_msg' }
      $uri = 'file:///' + ($full -replace '\\', '/')
      $params = if ($target -eq 'group') { @{ group_id = $id; message = @(@{ type = 'record'; data = @{ file = $uri } }) } }
                else { @{ user_id = $id; message = @(@{ type = 'record'; data = @{ file = $uri } }) } }
      $r = Invoke-OneBot $action $params
      if ($r.json -and $r.json.status -eq 'ok') {
        Add-Row 'OK' '发语音(file://)' ("message_id=" + $r.json.data.message_id)
      } else {
        Add-Row 'WARN' '发语音(file://)' (Show $r)
        $size = (Get-Item $full).Length
        if ($size -le 5MB) {
          $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($full))
          $params2 = if ($target -eq 'group') { @{ group_id = $id; message = @(@{ type = 'record'; data = @{ file = ('base64://' + $b64) } }) } }
                     else { @{ user_id = $id; message = @(@{ type = 'record'; data = @{ file = ('base64://' + $b64) } }) } }
          $r2 = Invoke-OneBot $action $params2
          if ($r2.json -and $r2.json.status -eq 'ok') {
            Add-Row 'OK' '发语音(base64)' ("message_id=" + $r2.json.data.message_id)
          } else {
            Add-Row 'FAIL' '发语音(base64)' (Show $r2)
          }
        } else {
          Add-Row 'INFO' '发语音(base64)' '文件超过 5MB，跳过 base64 试法'
        }
      }
    }
  }
}

Write-Host ""
$rows | Format-Table -AutoSize | Out-String -Width 160 | Write-Host

$fails = @($rows | Where-Object { $_.结果 -eq 'FAIL' }).Count
if ($fails -gt 0) {
  Write-Host "有 $fails 项 FAIL。常见原因：token 不对（401）、端口不对/服务没起（连接失败）、"
  Write-Host "录音段字段不一致（换 file:// / base64 试）、文件路径被限制（放进它的数据目录）。" -ForegroundColor Yellow
  exit 1
}
Write-Host "探针通过：HTTP、账号、发送链路都正常。" -ForegroundColor Green
