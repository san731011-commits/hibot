#!/bin/bash
# healthcheck_cron.sh - 정기 보안 감사 및 업데이트 확인

LOG_DIR="/tmp/openclaw/healthcheck"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y-%m-%d-%H%M)

echo "[$DATE] 보안 감사 시작..."
openclaw security audit --deep > "$LOG_DIR/audit-$DATE.log" 2>&1

echo "[$DATE] 업데이트 확인 시작..."
openclaw update status > "$LOG_DIR/update-$DATE.log" 2>&1

# 오래된 로그 정리 (30일 이상)
find "$LOG_DIR" -name "*.log" -mtime +30 -delete

echo "[$DATE] 완료!"
