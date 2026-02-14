#!/bin/bash
# Kimi 사용량 및 잔액 자동 확인 스크립트

# OpenClaw 설정에서 API 키 읽기
AUTH_FILE="/home/san/.openclaw/agents/main/agent/auth-profiles.json"
API_KEY=$(grep -o '"key":\s*"[^"]*"' "$AUTH_FILE" | grep -o 'sk-[^"]*' | head -1)

if [ -z "$API_KEY" ]; then
    echo "❌ Moonshot API 키를 찾을 수 없습니다"
    exit 1
fi

# Discord Webhook (환경변수 또는 설정 파일에서 읽기)
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"
if [ -f "/home/san/.openclaw/context-alert-config.json" ]; then
    DISCORD_WEBHOOK=$(grep -o '"webhookUrl":\s*"[^"]*"' /home/san/.openclaw/context-alert-config.json | cut -d'"' -f4)
fi

# 현재 시간
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 잔액 확인 API 호출
BALANCE_RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    "https://api.moonshot.ai/v1/users/me/balance")

# 응답 파싱
AVAILABLE=$(echo "$BALANCE_RESPONSE" | grep -o '"available_balance":[0-9.]*' | cut -d: -f2)
CASH=$(echo "$BALANCE_RESPONSE" | grep -o '"cash_balance":[0-9.]*' | cut -d: -f2)
VOUCHER=$(echo "$BALANCE_RESPONSE" | grep -o '"voucher_balance":[0-9.]*' | cut -d: -f2)

# 기본값 설정
AVAILABLE=${AVAILABLE:-"0"}
CASH=${CASH:-"0"}
VOUCHER=${VOUCHER:-"0"}

# 결과 출력
echo "[$TIMESTAMP] 💰 Kimi 잔액 현황"
echo "  사용 가능 잔액: \$$AVAILABLE"
echo "  캐시 잔액: \$$CASH"
echo "  바우처 잔액: \$$VOUCHER"

# 로그 파일에 저장
LOG_FILE="/tmp/kimi_balance.log"
echo "[$TIMESTAMP] balance=$AVAILABLE cash=$CASH voucher=$VOUCHER" >> "$LOG_FILE"

# Discord 알림 (잔액 10 위안 이하 또는 50 위안 이하)
if [ -n "$DISCORD_WEBHOOK" ]; then
    # 잔액 10 위안 이하 경고
    if [ "$(echo "$AVAILABLE < 10" | bc -l)" -eq 1 ] 2>/dev/null; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"🚨 **Kimi 잔액 부족 경고**\\n\\n현재 잔액: \$$AVAILABLE\\n캐시: \$$CASH\\n\\n⚠️ 충전이 필요합니다!\\n📅 $TIMESTAMP\", \"username\": \"Kimi Balance Alert\"}" \
            "$DISCORD_WEBHOOK" > /dev/null
        echo "  🚨 Discord 경고 알림 전송됨 (잔액 부족)"
    
    # 50 위안 이하 주의 알림
    elif [ "$(echo "$AVAILABLE < 50" | bc -l)" -eq 1 ] 2>/dev/null; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"⚠️ **Kimi 잔액 주의**\\n\\n현재 잔액: \$$AVAILABLE\\n캐시: \$$CASH\\n\\n잔액이 줄어들고 있습니다.\\n📅 $TIMESTAMP\", \"username\": \"Kimi Balance Alert\"}" \
            "$DISCORD_WEBHOOK" > /dev/null
        echo "  ⚠️ Discord 주의 알림 전송됨"
    fi
fi

echo ""
echo "✅ 확인 완료! 다음 확인: $(date -d '+1 day' '+%Y-%m-%d 09:00' 2>/dev/null || echo '내일')"
