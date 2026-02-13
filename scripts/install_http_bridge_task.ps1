param(
  [string]$TaskName = "BandAiCodexHttpBridge",
  [string]$RepoPath = "",
  [string]$PythonExe = "python",
  [int]$Port = 8787
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
  $RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$BridgeScript = Join-Path $RepoPath "scripts\codex_http_bridge.py"
if (!(Test-Path $BridgeScript)) {
  throw "Bridge script not found: $BridgeScript"
}

$Args = "`"$BridgeScript`" --repo-path `"$RepoPath`" --host 0.0.0.0 --port $Port"
$Action = New-ScheduledTaskAction -Execute $PythonExe -Argument $Args
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Settings = New-ScheduledTaskSettingsSet `
  -StartWhenAvailable `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $Action `
  -Trigger $Trigger `
  -Settings $Settings `
  -Description "Codex HTTP bridge for Discord/OpenClaw" `
  -Force | Out-Null

Write-Host "Scheduled task registered: $TaskName"
Write-Host "RepoPath: $RepoPath"
Write-Host "PythonExe: $PythonExe"
Write-Host "Port: $Port"
