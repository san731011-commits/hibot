param(
  [string]$TaskName = "BandAiDiscordCodexBridge",
  [string]$RepoPath = "",
  [string]$PythonExe = "python"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
  $RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$BotScript = Join-Path $RepoPath "scripts\discord_codex_bridge_bot.py"
if (!(Test-Path $BotScript)) {
  throw "Discord bridge script not found: $BotScript"
}

$Args = "`"$BotScript`" --repo-path `"$RepoPath`""
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
  -Description "Discord slash command bridge to Codex HTTP jobs" `
  -Force | Out-Null

Write-Host "Scheduled task registered: $TaskName"
Write-Host "RepoPath: $RepoPath"
Write-Host "PythonExe: $PythonExe"
