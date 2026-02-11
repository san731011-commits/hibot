#!/usr/bin/env bash
# context_monitor.sh - 모니터 컨텍스트 사용량 체크 및 알림

THRESHOLD=90
LOG_FILE=/tmp/openclaw-context-monitor.log
STATE_FILE=/tmp/openclaw-context-state.json

# 현재 컨텍스트 사용량 확인 (OpenClaw 상태 API나 로그에서 파싱)
check_context() {
    # 실제 구현은 OpenClaw의 상태 엔드포인트나 로그 파싱 필요
    # 여기서는 예시 구현
    
    # OpenClaw 세션 상태 확인 (가상)
    # 실제로는 OpenClaw의 상태 API를 호출하거나 로그를 파싱해야 함
    
    # 예시: 로그에서 컨텍스트 사용량 추출
    if [ -f /tmp/openclaw/latest-session.log ]; then
        CONTEXT_PERCENT=$(grep -o "Context: [0-9]*%" /tmp/openclaw/latest-session.log | tail -1 | grep -o "[0-9]*")
        echo "$CONTEXT_PERCENT"
    else
        echo "0"
    fi
}

# 알림 전송
send_alert() {
    local usage=$1
    local message="⚠️ OpenClaw 컨텍스트 ${usage}% 도달! 정리가 필요합니다."
    
    # Discord로 알림 (curl 사용)
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"content\":\"$message\"}" \
        "YOUR_DISCORD_WEBHOOK_URL" 2>/dev/null || true
    
    # 로그 기록
    echo "$(date): ALERT - Context at ${usage}%" >> "$LOG_FILE"
    
    # 상태 파일 업데이트
    cat > "$STATE_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "contextPercent": $usage,
  "alertSent": true,
  "action": "cleanup_needed"
}
EOF
}

# 자동 정리 제안
propose_cleanup() {
    local message="💡 컨텍스트 정리 제안:\n"
    message+="1. 새 세션 시작\n"
    message+="2. 중요 내용 메모리 저장\n" 
    message+="3. 오래된 대화 정리\n"
    message+="\n자동 정리를 원하시면 '정리'라고 답해주세요."
    
    # Discord 알림
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"content\":\"$message\"}" \
        "YOUR_DISCORD_WEBHOOK_URL" 2>/dev/null || true
}

# 메인
main() {
    USAGE=$(check_context)
    
    if [ "$USAGE" -ge "$THRESHOLD" ]; then
        send_alert "$USAGE"
        propose_cleanup
    fi
    
    # 상태 저장
    cat > "$STATE_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "contextPercent": $USAGE,
  "threshold": $THRESHOLD,
  "checked": true
}
EOF
}

main
