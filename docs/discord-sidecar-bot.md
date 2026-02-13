# Discord Sidecar Bot (OpenClaw 명령 연결)

OpenClaw 소스 직접 수정 없이 Discord slash command를 HTTP 브리지로 연결합니다.

파일:
- `scripts/discord_codex_bridge_bot.py`

## 동작
1. Discord에서 `/task <prompt>` 실행
2. 봇이 HTTP 브리지 `POST /jobs` 호출
3. 즉시 `job_id` 응답
4. 백그라운드 폴링 후 완료 결과를 같은 채널에 회신

## 사전 준비
1. Python 의존성 설치
```bash
pip install discord.py
```

2. `.worker.env` 설정
```env
BRIDGE_TOKEN=...
BRIDGE_BASE_URL=http://127.0.0.1:8787
DISCORD_BOT_TOKEN=...
DISCORD_GUILD_ID=1469645949436690502
DISCORD_ALLOWED_CHANNELS=1469645949956526145
```

## 실행
```bash
python3 scripts/discord_codex_bridge_bot.py --repo-path .
```

## 제공 slash commands
- `/task prompt:<text>`
- `/status job_id:<uuid>`
- `/health`

## Windows 자동 시작
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_discord_bridge_task.ps1 `
  -TaskName "BandAiDiscordCodexBridge" `
  -RepoPath "C:\work\band-ai-dashboard" `
  -PythonExe "python"
```
