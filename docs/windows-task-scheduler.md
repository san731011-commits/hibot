# Windows Task Scheduler (2번)

집 Windows 부팅 시 워커를 자동 시작합니다.

## 사전 조건
- Python 설치
- 저장소 경로 예: `C:\work\band-ai-dashboard`
- `C:\work\band-ai-dashboard\.worker.env` 작성 완료

## 설치
PowerShell(관리자)에서:

```powershell
cd C:\work\band-ai-dashboard
powershell -ExecutionPolicy Bypass -File .\scripts\install_worker_task.ps1 `
  -TaskName "BandAiGithubWorker" `
  -RepoPath "C:\work\band-ai-dashboard" `
  -PythonExe "python" `
  -IntervalSec 45
```

## 확인
```powershell
Get-ScheduledTask -TaskName "BandAiGithubWorker"
Start-ScheduledTask -TaskName "BandAiGithubWorker"
```

## 삭제
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall_worker_task.ps1 `
  -TaskName "BandAiGithubWorker"
```
