# OpenClaw -> GitHub (MVP)

## 목적
OpenClaw에서 받은 요청을 GitHub `Task` 이슈로 등록한다.

## 사전 조건
- `GITHUB_TOKEN` 환경변수 설정
- 대상 저장소: `san731011-commits/band-ai-dashboard`

## 호출 예시
```bash
./scripts/create_task_issue.sh \
  "대시보드 알림 UI 개선" \
  "알림 카드에 시간/우선순위 배지를 추가하고 모바일 레이아웃을 정리"
```

## OpenClaw 연동 아이디어
- 메신저 명령 예: `/task <제목> | <목표>`
- 파서에서 제목/목표 분리 후 `create_task_issue.sh` 호출
- 반환 문자열(`Created issue #...`)을 메신저에 그대로 회신
