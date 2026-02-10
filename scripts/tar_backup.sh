#!/usr/bin/env bash
# tar_backup.sh
# Usage: ./tar_backup.sh [output-dir]
# Creates a compressed tar.gz of selected config files and keeps a limited number of recent archives.
set -euo pipefail
cd "$(dirname "$0")/.."
WORKDIR=$(pwd)
OUTDIR=${1:-"$WORKDIR/backups"}
KEEP=${KEEP:-5}
mkdir -p "$OUTDIR"
TS=$(date +%Y%m%d-%H%M%S)
OUTFILE="$OUTDIR/backup-config-$TS.tar.gz"
# Adjust includes/excludes to avoid large dirs (e.g., /var/lib/docker)
INCLUDE=(
  ".openclaw/workspace/*.yml"
  ".openclaw/workspace/config"
  "docker-compose.yml"
  "scripts"
  "*.env"
)
EXCLUDE=(
  "var/lib/docker"
  "**/node_modules"
)
# Build tar command
TAR_EXCLUDE_ARGS=()
for e in "${EXCLUDE[@]}"; do TAR_EXCLUDE_ARGS+=(--exclude="$e"); done
TAR_INCLUDE_ARGS=()
for i in "${INCLUDE[@]}"; do TAR_INCLUDE_ARGS+=("$i"); done
# Create archive
echo "Creating $OUTFILE"
tar czf "$OUTFILE" "${TAR_INCLUDE_ARGS[@]}" "${TAR_EXCLUDE_ARGS[@]}" || { echo "tar failed"; exit 1; }
# Prune old backups
ls -1t "$OUTDIR"/backup-config-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm --
echo "Backup complete: $OUTFILE"
