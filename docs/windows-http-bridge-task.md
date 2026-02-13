# Windows 자동 시작 (HTTP Bridge)

집 Windows 부팅 시 HTTP 브리지를 자동 시작합니다.

## 사전 조건
- Python 설치
- 저장소 경로 예: `C:\work\band-ai-dashboard`
- `.worker.env`에 `BRIDGE_TOKEN` 설정 완료

## 등록
PowerShell(관리자):

```powershell
cd C:\work\band-ai-dashboard
powershell -ExecutionPolicy Bypass -File .\scripts\install_http_bridge_task.ps1 `
  -TaskName "BandAiCodexHttpBridge" `
  -RepoPath "C:\work\band-ai-dashboard" `
  -PythonExe "python" `
  -Port 8787
```

## 확인/수동 실행
```powershell
Get-ScheduledTask -TaskName "BandAiCodexHttpBridge"
Start-ScheduledTask -TaskName "BandAiCodexHttpBridge"
```

## 삭제
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall_http_bridge_task.ps1 `
  -TaskName "BandAiCodexHttpBridge"
```
