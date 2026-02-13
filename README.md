# band-ai-dashboard

OpenClaw/Discord 요청을 Codex로 처리하기 위한 운영 저장소입니다.

## 목표
- Discord 요청을 원격으로 빠르게 처리
- Codex 실행 결과를 안전하게 전달
- 필요 시 GitHub 이슈/PR 흐름도 함께 지원

## 권장 운영 방식 (현재)
1. OpenClaw가 `POST /jobs` 호출 (즉시 `job_id` 수신)
2. OpenClaw가 `GET /jobs/<job_id>`로 상태 조회
3. 완료 시 Discord에 결과 요약 전송

관련 문서:
- `docs/http-bridge.md`
- `docs/windows-http-bridge-task.md`

## 기본 흐름
1. OpenClaw/Discord 요청을 `Task Request` 이슈로 등록
2. 작업자는 이슈 번호로 브랜치 생성 (`task/<issue-number>-short-name`)
3. 구현 후 PR 생성, 체크리스트 완료
4. 머지 후 결과 링크를 메신저에 회신

## 브랜치/커밋 규칙
- 브랜치: `task/<issue-number>-<slug>`
- 커밋: `feat: ...`, `fix: ...`, `chore: ...`, `docs: ...`

## 빠른 시작
1. GitHub에서 `New issue` → `Task Request` 선택
2. 요청 내용 작성 후 이슈 생성
3. 로컬에서 작업:

```bash
git fetch origin
git checkout -b task/1-initial-setup
# 작업
git add .
git commit -m "feat: add initial workflow templates"
git push -u origin task/1-initial-setup
```

4. GitHub에서 PR 생성 후 템플릿 체크

## 토큰으로 이슈 자동 생성
`GITHUB_TOKEN`이 설정되어 있으면 스크립트로 작업 이슈를 만들 수 있습니다.

```bash
export GITHUB_TOKEN="<fine-grained-pat>"
./scripts/create_task_issue.sh "로그인 에러 문구 수정" "로그인 실패 메시지를 한국어로 통일"
```

선택 환경변수:
- `GITHUB_OWNER` (기본값: `san731011-commits`)
- `GITHUB_REPO` (기본값: `band-ai-dashboard`)

## 자동 운영 세트
1. 워커 자동 처리: `scripts/github_task_worker.py`
2. Windows 시작 자동실행: `scripts/install_worker_task.ps1`
3. Discord/OpenClaw 명령 브리지: `scripts/openclaw_github_bridge.py`
4. HTTP Codex 브리지: `scripts/codex_http_bridge.py`
5. HTTP 브리지 자동실행: `scripts/install_http_bridge_task.ps1`
6. OpenClaw -> HTTP 명령 브리지: `scripts/openclaw_http_bridge.py`

문서:
- `docs/worker-automation.md`
- `docs/windows-task-scheduler.md`
- `docs/discord-commands.md`
- `docs/openclaw-github-bridge.md`
- `docs/http-bridge.md`
- `docs/windows-http-bridge-task.md`
- `docs/openclaw-http-commands.md`
