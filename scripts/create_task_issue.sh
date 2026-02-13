#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 \"<title>\" \"<objective>\" [priority]"
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN is not set."
  exit 1
fi

OWNER="${GITHUB_OWNER:-san731011-commits}"
REPO="${GITHUB_REPO:-band-ai-dashboard}"
TITLE="$1"
OBJECTIVE="$2"
PRIORITY="${3:-P1 - 높음}"

read -r -d '' BODY <<EOF || true
## 작업 목표
- ${OBJECTIVE}

## 완료 기준
- [ ] 요구사항 충족
- [ ] 테스트/검증 완료
- [ ] PR 생성 및 리뷰 가능 상태

## 우선순위
${PRIORITY}
EOF

PAYLOAD=$(TITLE="${TITLE}" BODY="${BODY}" python3 - <<'PY'
import json
import os

print(json.dumps({
    "title": f"[Task] {os.environ['TITLE']}",
    "body": os.environ["BODY"],
    "labels": ["task"],
}, ensure_ascii=False))
PY
)

RESP=$(
  curl -sS -f -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${OWNER}/${REPO}/issues" \
    -d "${PAYLOAD}"
)

ISSUE_URL=$(printf '%s\n' "${RESP}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["html_url"])')
ISSUE_NO=$(printf '%s\n' "${RESP}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["number"])')

echo "Created issue #${ISSUE_NO}: ${ISSUE_URL}"
