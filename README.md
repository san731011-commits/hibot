# band-ai-dashboard

GitHub Issue/PR 기반으로 OpenClaw 요청을 처리하기 위한 최소 운영 저장소입니다.

## 목표
- 메신저 요청을 이슈로 표준화
- Codex 작업을 PR로 검토 가능하게 관리
- 결과를 다시 메신저로 전달할 때 근거 링크(이슈/PR) 확보

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
