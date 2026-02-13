# GitHub MVP 운영 순서

## 1) 요청 접수
- Discord/OpenClaw 요청을 확인
- GitHub에서 `Task Request` 이슈 생성

## 2) 작업 시작
- 이슈 번호 확인 후 브랜치 생성
- 브랜치 예시: `task/12-fix-login-error`

```bash
git fetch origin
git checkout -b task/12-fix-login-error origin/main
```

## 3) 구현/검증
- 코드 수정
- 필요한 테스트 실행

## 4) PR 생성
- 원격으로 브랜치 푸시
- PR 템플릿 항목 작성
- 이슈 연결 (`Closes #12`)

## 5) 완료 회신
- PR 머지 후 Discord/OpenClaw에 전달:
  - 이슈 링크
  - PR 링크
  - 반영 요약(3줄)
