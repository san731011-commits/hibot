#!/usr/bin/env bash
# context_alert.sh - OpenClaw 컨텍스트 90% 알림 시스템

set -euo pipefail

CONFIG_FILE="/home/san/.openclaw/context-alert-config.json"
LOG_FILE="/tmp/openclaw/context-alert.log"
ALERT_SENT_FILE="/tmp/openclaw/alert-sent"

# 기본 설정
THRESHOLD=90
COOLDOWN_MINUTES=30

# 설정 로드
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        THRESHOLD=$(jq -r '.threshold // 90' "$CONFIG_FILE" 2>/dev/null || echo "90")
        DISCORD_WEBHOOK=$(jq -r '.discordWebhook // empty' "$CONFIG_FILE" 2>/dev/null || true)
    fi
}

# 로그 함수
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# OpenClaw 상태 확인
get_context_usage() {
    # 방법 1: OpenClay gateway 상태 API 호출
    local gateway_url="http://127.0.0.1:18789"
    local auth_token=""
    
    # 설정에서 토큰 읽기
    if [ -f /home/san/.openclaw/openclaw.json ]; then
        auth_token=$(grep -o '"token": "[^"]*"' /home/san/.openclaw/openclaw.json | grep -A2 gateway | head -1 | cut -d'"' -f4 || true)
    fi
    
    # API 호출 시도
    local response
    if [ -n "$auth_token" ]; then
        response=$(curl -s -H "Authorization: Bearer $auth_token" \
            "$gateway_url/status" 2>/dev/null || echo "")
    fi
    
    # 컨텍스트 퍼센트 추출
    if [ -n "$response" ]; then
        echo "$response" | jq -r '.context // .contextPercent // 0' 2>/dev/null || echo "0"
    else
        # 방법 2: 세션 파일에서 추정
        estimate_from_session
    fi
}

# 세션 파일에서 컨텍스트 추정
estimate_from_session() {
    local session_file="/home/san/.openclaw/agents/main/sessions/sessions.json"
    
    if [ -f "$session_file" ]; then
        # 세션 크기로 대략적 추정 (매우 rough)
        local size=$(stat -f%z "$session_file" 2>/dev/null || stat -c%s "$session_file" 2>/dev/null || echo "0")
        # 대략 1KB = 1000 토큰으로 가정, 256K 컨텍스트 기준
        local estimated=$((size / 4000))
        if [ "$estimated" -gt 100 ]; then
            echo "100"
        else
            echo "$estimated"
        fi
    else
        echo "0"
    fi
}

# Discord 알림 전송
send_discord_alert() {
    local usage=$1
    local message="🚨 **OpenClaw 컨텍스트 알림**\n\n"
    message+="컨텍스트 사용량이 **${usage}%**에 도달했습니다!\n\n"
    message+="**권장 조치:**\n"
    message+="1️⃣ 새 세션 시작: \`/status\` 확인 후 정리\n"
    message+="2️⃣ 중요 내용 저장: 메모리 파일 업데이트\n"
    message+="3️⃣ 자동 정리: \`컨텍스트 정리\` 명령\n\n"
    message+="_자동 알림 시스템_"
    
    # 설정에서 웹훅 URL 가져오기
    if [ -n "${DISCORD_WEBHOOK:-}" ]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"$message\"}" \
            "$DISCORD_WEBHOOK" > /dev/null 2>&1 || log "Discord 알림 전송 실패"
    fi
    
    # 채널로 직접 메시지 (OpenClaw 메시지 툴 사용)
    # 이 부분은 OpenClaw 남부에서 처리
    log "Discord 알림 전송 시도: ${usage}%"
}

# 알림 쿨다운 체크
check_cooldown() {
    if [ -f "$ALERT_SENT_FILE" ]; then
        local last_sent=$(cat "$ALERT_SENT_FILE")
        local now=$(date +%s)
        local diff=$((now - last_sent))
        local cooldown_seconds=$((COOLDOWN_MINUTES * 60))
        
        if [ "$diff" -lt "$cooldown_seconds" ]; then
            return 1  # 쿨다운 중
        fi
    fi
    return 0  # 알림 가능
}

# 알림 기록
record_alert() {
    date +%s > "$ALERT_SENT_FILE"
}

# 상태 저장
save_status() {
    local usage=$1
    local status=$2
    
    cat > "/tmp/openclaw/context-status.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "contextPercent": $usage,
  "threshold": $THRESHOLD,
  "status": "$status",
  "alertCooldownMinutes": $COOLDOWN_MINUTES
}
EOF
}

# 메인 로직
main() {
    load_config
    
    log "컨텍스트 모니터링 시작"
    
    local usage
    usage=$(get_context_usage)
    
    log "현재 컨텍스트 사용량: ${usage}%"
    
    if [ "$usage" -ge "$THRESHOLD" ]; then
        if check_cooldown; then
            log "⚠️ 임계값 도달: ${usage}% >= ${THRESHOLD}%"
            send_discord_alert "$usage"
            record_alert
            save_status "$usage" "alert_sent"
        else
            log "ℹ️ 임계값 도달했으나 쿨다운 중"
            save_status "$usage" "cooldown"
        fi
    else
        save_status "$usage" "normal"
    fi
}

# 설정 파일 생성 함수
init_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
{
  "threshold": 90,
  "cooldownMinutes": 30,
  "discordWebhook": "",
  "autoCleanup": false,
  "notifyMethods": ["log", "discord"]
}
EOF
    log "설정 파일 생성됨: $CONFIG_FILE"
}

# 초기화
if [ "${1:-}" = "init" ]; then
    init_config
    exit 0
fi

main
