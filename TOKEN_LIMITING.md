# Token Rate Limiting Configuration Summary

## 적용된 Rate Limiting 설정

### 1. 동시 처리량 제한 (Concurrency Control) ✅
```json
"agents.defaults.maxConcurrent": 1        // 한 번에 하나의 메시지만 처리
"agents.defaults.subagents.maxConcurrent": 1  // 서브에이전트도 순차 처리
```

### 2. 요청 간 지연 시간 (Request Throttling) ✅
```json
"messages.inbound.debounceMs": 500        // 0.5초 디바운스
"agents.defaults.humanDelay": {
  "mode": "custom",
  "minMs": 300,      // 최소 0.3초 지연
  "maxMs": 800       // 최대 0.8초 지연
}
```

### 3. 큐 깊이 제한 (Queue Cap) ✅
```json
"messages.queue.cap": 5                   // 최대 5개 요청만 대기
"messages.queue.drop": "new"              // 초과 시 새 요청 버림
```

### 4. TPM 900K 자동 차단 시스템 (Watchdog) ✅
- **모니터링**: 1분마다 토큰 사용량 체크 (Cron job)
- **임계점**: 900,000 TPM (90%) 도달 시 자동 쿨다운
- **쿨다운**: 30초간 모든 요청 차단
- **스크립트**: `~/.openclaw/workspace/scripts/token-watchdog.js`

---

## 사용 방법

### 워치독 수동 확인
```bash
# 현재 상태 확인
node ~/.openclaw/workspace/scripts/token-watchdog.js status

# 요청 전 체크 (차단 시 exit code 1)
node ~/.openclaw/workspace/scripts/token-watchdog.js check

# 요청 기록 (토큰 사용량 추적)
node ~/.openclaw/workspace/scripts/token-watchdog.js record 2000
```

### 쉘 스크립트 통합
```bash
# LLM 호출 전에 삽입
source ~/.openclaw/workspace/scripts/token-check.sh
if [ $? -ne 0 ]; then
  echo "Rate limit exceeded"
  exit 1
fi
```

---

## 설정 파일 위치

| 파일 | 경로 |
|------|------|
| OpenClaw Config | `~/.openclaw/openclaw.json` |
| Token Watchdog | `~/.openclaw/workspace/scripts/token-watchdog.js` |
| Token Check Wrapper | `~/.openclaw/workspace/scripts/token-check.sh` |
| Watchdog State | `~/.openclaw/token-watchdog.json` |
| Watchdog Log | `~/.openclaw/logs/watchdog.log` |

---

## 모니터링

### Cron Job 상태 확인
```bash
openclaw cron list
```

### 로그 실시간 확인
```bash
tail -f ~/.openclaw/logs/watchdog.log
```

---

## 비상시 조치

TPM 한도에 걸렸을 때 즉시 해제:
```bash
# 모델을 Gemini 2 Flash로 전환 (4M TPM)
openclaw gateway config.patch '{"agents":{"defaults":{"model":{"primary":"google/gemini-2.0-flash-exp"}}}}'
```

---

## 적용 일시
- 2026-02-11 20:05 (KST)
