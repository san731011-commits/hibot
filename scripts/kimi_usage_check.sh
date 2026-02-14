#!/bin/bash
# Kimi 사용량 자동 확인 스크립트

API_KEY="${MOONSHOT_API_KEY:-YOUR_API_KEY_HERE}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"

# 잔액 확인
check_balance() {
    local response=$(curl -s -X GET \
        -H "Authorization: Bearer $API_KEY" \
        "https://api.moonshot.ai/v1/users/me/balance" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response" | grep -o '"balance":[0-9.]*' | cut -d: -f2
    else
        echo "error"
    fi
}

# 사용량 확인 (만약 API 제공된다면)
check_usage() {
    # Moonshot API 사용량 엔드포인트 (공식 문서 확인 필요)
    echo "usage_stats_placeholder"
}

# 메인 실행
main() {
    local balance=$(check_balance)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$balance" = "error" ]; then
        echo "[$timestamp] ❌ API 호출 실패"
        exit 1
    fi
    
    echo "[$timestamp] 💰 Kimi 잔액: $balance"
    
    # Discord 알림 (선택사항)
    if [ -n "$DISCORD_WEBHOOK" ] && [ "$(echo "$balance < 10" | bc -l)" -eq 1 ]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"⚠️ Kimi 잔액 부족! 현재 잔액: $balance\",\"username\":\"Kimi Usage Alert\"}" \
            "$DISCORD_WEBHOOK" > /dev/null
    fi
}

main "$@"
