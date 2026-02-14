#!/bin/bash
# Smart Gateway Restart Script
# 포트 충돌 자동 감지 및 해결

echo "🔄 OpenClaw Gateway 스마트 재시작"
echo "================================"

# 1. 현재 상태 확인
echo "📊 현재 상태 확인..."
openclaw status 2>/dev/null | grep -E "(Status|PID)" || echo "   Gateway: 중지됨 또는 확인 불가"

# 2. 포트 18789 점유 프로세스 확인
echo ""
echo "🔍 포트 18789 확인..."
PORT_PID=$(sudo lsof -t -i :18789 2>/dev/null)

if [ -n "$PORT_PID" ]; then
    echo "   ⚠️ 포트 점유 감지! PID: $PORT_PID"
    echo "   🛑 프로세스 종료 중..."
    sudo kill -15 $PORT_PID 2>/dev/null
    sleep 2
    
    # 여전히 살아있으면 강제 종료
    if sudo kill -0 $PORT_PID 2>/dev/null; then
        echo "   💀 강제 종료..."
        sudo kill -9 $PORT_PID 2>/dev/null
        sleep 1
    fi
    echo "   ✅ 포트 정리 완료"
else
    echo "   ✅ 포트 비어있음"
fi

# 3. 남은 OpenClaw 프로세스 정리
echo ""
echo "🧹 남은 프로세스 정리..."
REMAINING=$(pgrep -f "openclaw" | wc -l)
if [ $REMAINING -gt 0 ]; then
    sudo pkill -15 -f "openclaw" 2>/dev/null
    sleep 2
    sudo pkill -9 -f "openclaw" 2>/dev/null
    echo "   ✅ $REMAINING개 프로세스 정리"
else
    echo "   ✅ 깨끗함"
fi

# 4. 포트 최종 확인
echo ""
echo "🔍 포트 최종 확인..."
if sudo lsof -i :18789 >/dev/null 2>&1; then
    echo "   ❌ 여전히 포트 사용 중! 수동 확인 필요"
    sudo lsof -i :18789
    exit 1
else
    echo "   ✅ 포트 18789 사용 가능"
fi

# 5. Gateway 재시작
echo ""
echo "🚀 Gateway 재시작..."
openclaw gateway start &
START_PID=$!

# 6. 시작 대기 및 확인
echo "   ⏳ 시작 대기 중..."
sleep 5

if ps -p $START_PID >/dev/null 2>&1; then
    echo ""
    echo "✅ Gateway 프로세스 실행 중"
    sleep 3
    
    # 상태 확인
    echo ""
    echo "📋 상태 확인:"
    openclaw status 2>/dev/null | head -10 || echo "   상태 확인 중..."
    
    echo ""
    echo "🎉 재시작 완료!"
else
    echo ""
    echo "❌ 시작 실패! 로그 확인:"
    openclaw logs --lines 20 2>/dev/null || tail -20 /tmp/openclaw/*.log 2>/dev/null
    exit 1
fi
