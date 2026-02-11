#!/bin/bash
# Token Rate Limit Wrapper
# LLM 호출 전에 토큰 사용량을 체크하고 쿨다운이 필요하면 대기

WATCHDOG="${HOME}/.openclaw/workspace/scripts/token-watchdog.js"
NODE="$(which node 2>/dev/null || echo '/usr/bin/node')"

# 체크 실행
if [ ! -f "$WATCHDOG" ]; then
    echo "Watchdog script not found: $WATCHDOG" >&2
    exit 0  # 차단하지 않고 진행
fi

# 토큰 사용량 체크
RESULT=$("$NODE" "$WATCHDOG" check 2>/dev/null)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    # 차단됨 - 이유 출력
    REASON=$(echo "$RESULT" | grep -o '"message": "[^"]*"' | cut -d'"' -f4)
    REMAINING=$(echo "$RESULT" | grep -o '"remainingSeconds": [0-9]*' | grep -o '[0-9]*')
    
    echo "⚠️ $REASON" >&2
    
    if [ -n "$REMAINING" ] && [ "$REMAINING" -gt 0 ]; then
        echo "⏳ ${REMAINING}초 대기 중..." >&2
        sleep "$REMAINING"
    fi
fi

# 성공적으로 통과 (또는 대기 후)
exit 0
