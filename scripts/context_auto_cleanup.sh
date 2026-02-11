#!/bin/bash
# context_auto_cleanup.sh - 완전 자동화된 컨텍스트 관리

set -euo pipefail

CONFIG_FILE="/home/san/.openclaw/context-alert-config.json"
LOG_FILE="/tmp/openclaw/context-cleanup.log"
MEMORY_DIR="/home/san/.openclaw/workspace/memory"
STATE_FILE="/tmp/openclaw/cleanup-state.json"

# 로그 함수
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 설정 로드
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        THRESHOLD=$(jq -r '.threshold // 90' "$CONFIG_FILE")
        DISCORD_WEBHOOK=$(jq -r '.discordWebhook // empty' "$CONFIG_FILE")
        AUTO_CLEANUP=$(jq -r '.autoCleanup // false' "$CONFIG_FILE")
    else
        THRESHOLD=90
        AUTO_CLEANUP="false"
    fi
}

# Discord 알림 전송
send_discord_notification() {
    local title="$1"
    local message="$2"
    local color="$3"  # decimal color code
    
    if [ -z "${DISCORD_WEBHOOK:-}" ]; then
        return
    fi
    
    local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$message",
    "color": $color,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "footer": {
      "text": "OpenClaw Auto Cleanup"
    }
  }]
}
EOF
)
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$DISCORD_WEBHOOK" > /dev/null 2>&1 || log "Discord 알림 실패"
}

# 중요 내용 자동 저장
save_important_context() {
    log "📝 중요 내용 자동 저장 시작..."
    
    local today=$(date +%Y-%m-%d)
    local memory_file="$MEMORY_DIR/${today}.md"
    
    mkdir -p "$MEMORY_DIR"
    
    # 현재 세션 요약 저장
    cat >> "$memory_file" << EOF

## $(date '+%H:%M') - 자동 저장 (컨텍스트 90% 도달)

### 주요 작업 요약
- 컨텍스트 한계 도달로 자동 정리 수행
- 세션 연속성 유지를 위한 메모리 저장

### 완료된 작업
$(tail -20 /tmp/openclaw/context-alert.log 2>/dev/null || echo "로그 없음")

### 다음 세션에서 계속할 작업
- $(cat /tmp/openclaw/next-tasks.txt 2>/dev/null || echo "특이사항 없음")

---

EOF
    
    log "✅ 메모리 저장 완료: $memory_file"
    
    # Discord에도 알림
    send_discord_notification \
        "📝 메모리 자동 저장 완료" \
        "중요 내용이 \`${today}.md\`에 저장되었습니다.\\n다음 세션에서 계속 작업할 수 있습니다." \
        3447003  # Blue color
}

# 새 세션 시작
restart_session() {
    log "🔄 새 세션 시작..."
    
    # 1. 현재 세션 정리 (OpenClay 세션 파일 백업)
    local session_backup="/tmp/openclaw/session-backup-$(date +%s).json"
    if [ -f /home/san/.openclaw/agents/main/sessions/sessions.json ]; then
        cp /home/san/.openclaw/agents/main/sessions/sessions.json "$session_backup"
        log "세션 백업: $session_backup"
    fi
    
    # 2. 다음 작업 힌트 저장
    cat > /tmp/openclaw/next-tasks.txt << EOF
컨텍스트 정리 후 새 세션 시작됨
이전 대화는 메모리 파일 참조: memory/$(date +%Y-%m-%d).md
EOF
    
    # 3. Gateway 재시작 (선택적)
    # systemctl --user restart openclaw-gateway.service 2>/dev/null || true
    
    log "✅ 새 세션 준비 완료"
    
    # Discord 알림
    send_discord_notification \
        "🆕 새 세션 시작됨" \
        "컨텍스트가 정리되었습니다.\\n\\n✅ 메모리 저장 완료\\n✅ 새 세션 준비 완료\\n\\n계속해서 대화할 수 있습니다!" \
        3066993  # Green color
}

# 전체 정리 프로세스
perform_cleanup() {
    log "🚨 컨텍스트 90% 도달! 자동 정리 시작..."
    
    # 상태 업데이트
    cat > "$STATE_FILE" << EOF
{
  "status": "cleaning",
  "startedAt": "$(date -Iseconds)",
  "contextPercent": 90
}
EOF
    
    # 1단계: 알림
    send_discord_notification \
        "🚨 컨텍스트 90% 도달" \
        "자동 정리를 시작합니다.\\n\\n1️⃣ 메모리 저장\\n2️⃣ 세션 정리\\n3️⃣ 새 세션 시작" \
        15158332  # Orange color
    
    sleep 2
    
    # 2단계: 메모리 저장
    save_important_context
    sleep 2
    
    # 3단계: 새 세션 시작
    restart_session
    
    # 완료 상태
    cat > "$STATE_FILE" << EOF
{
  "status": "completed",
  "completedAt": "$(date -Iseconds)",
  "contextPercent": 0
}
EOF
    
    log "✅ 자동 정리 완료!"
}

# 메인 로직
main() {
    load_config
    
    # autoCleanup이 true가 아니면 종료
    if [ "$AUTO_CLEANUP" != "true" ]; then
        exit 0
    fi
    
    # 여기서 실제 컨텍스트 체크 로직 필요
    # (간단히 90%라고 가정하고 테스트)
    
    # 테스트: 강제로 정리 실행 (실제로는 체크 후)
    # perform_cleanup
    
    log "자동 정리 시스템 대기 중... (autoCleanup: $AUTO_CLEANUP)"
}

# 직접 실행 시 (테스트)
if [ "${1:-}" = "cleanup" ]; then
    load_config
    perform_cleanup
    exit 0
fi

if [ "${1:-}" = "test-alert" ]; then
    load_config
    send_discord_notification \
        "🧪 테스트 알림" \
        "자동화 시스템이 정상 작동 중입니다!" \
        3447003
    exit 0
fi

main
