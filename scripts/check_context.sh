#!/bin/bash
# check_context.sh - 현재 컨텍스트 상태 수동 확인

echo "🦞 OpenClaw 컨텍스트 상태 확인"
echo "================================"
echo ""

# 설정 로드
CONFIG="/home/san/.openclaw/context-alert-config.json"
THRESHOLD=90
if [ -f "$CONFIG" ]; then
    THRESHOLD=$(jq -r '.threshold // 90' "$CONFIG" 2>/dev/null || echo "90")
fi

echo "📊 알림 임계값: ${THRESHOLD}%"
echo ""

# 현재 상태 확인
if [ -f "/tmp/openclaw/context-status.json" ]; then
    echo "📈 현재 상태:"
    cat "/tmp/openclaw/context-status.json" | jq . 2>/dev/null || cat "/tmp/openclaw/context-status.json"
else
    echo "ℹ️ 아직 상태 정보가 없습니다. (몇 분 후 다시 확인)"
fi

echo ""
echo "🔧 사용 가능한 명령어:"
echo "  - 현재 상태: /status"
echo "  - 컨텍스트 정리: '정리' 또는 '새 세션'"
echo "  - 설정 변경: ~/.openclaw/context-alert-config.json"
echo ""
echo "📝 로그 위치: /tmp/openclaw/context-alert.log"
