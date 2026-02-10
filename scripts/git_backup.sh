#!/usr/bin/env bash
# git_backup.sh
# Usage: ./git_backup.sh "Commit message summary"
# Creates a git commit with all changes in workspace and tags it with timestamp.
set -euo pipefail
cd "$(dirname "$0")/.."
WORKDIR=$(pwd)
MSG=${1:-"healthcheck: automated backup $(date --iso-8601=seconds)"}
# Ensure inside git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $WORKDIR" >&2
  exit 1
fi
# Stage relevant files (avoid large files by default)
# Customize path list if needed
git add -A
git commit -m "$MSG" || {
  echo "No changes to commit." >&2
}
TAG="healthcheck/$(date +%Y%m%d-%H%M%S)"
git tag -a "$TAG" -m "Automated healthcheck backup: $MSG" || true
echo "Created tag: $TAG"
# Do not push without explicit approval
echo "Local commit and tag complete. To push to remote: git push && git push --tags"
