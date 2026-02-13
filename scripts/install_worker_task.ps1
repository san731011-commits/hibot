param(
  [string]$TaskName = "BandAiGithubWorker",
  [string]$RepoPath = "",
  [string]$PythonExe = "python",
  [int]$IntervalSec = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
  $RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$WorkerScript = Join-Path $RepoPath "scripts\github_task_worker.py"
if (!(Test-Path $WorkerScript)) {
  throw "Worker script not found: $WorkerScript"
}

$Args = "`"$WorkerScript`" --repo-path `"$RepoPath`" --loop --interval $IntervalSec"
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
  -Description "GitHub task worker for OpenClaw/Codex automation" `
  -Force | Out-Null

Write-Host "Scheduled task registered: $TaskName"
Write-Host "RepoPath: $RepoPath"
Write-Host "PythonExe: $PythonExe"
