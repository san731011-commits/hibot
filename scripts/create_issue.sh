#!/bin/bash
# GitHub 이슈 생성 스크립트 (간단 버전)
# 사용법: ./create_issue.sh "제목" "내용"

TITLE="${1:-작업 요청}"
BODY="${2:-자동 생성된 작업입니다}"

# GitHub API로 이슈 생성
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/san731011-commits/band-ai-dashboard/issues \
  -d "{
    \"title\": \"$TITLE\",
    \"body\": \"$BODY\",
    \"labels\": [\"codex-task\"]
  }" | jq -r '"이슈 생성됨: #\(.number) - \(.title)\n링크: \(.html_url)"'
