# 토큰 사용량 제한 및 요청 속도 제한 설정 문서
# Token Rate Limiting & Request Throttling Configuration

## 적용된 설정 (Applied Settings)

### 1. 동시 처리 제한 (Concurrency Limits) ✅
**파일:** `/home/san/.openclaw/openclaw.json`

```json
"agents": {
  "defaults": {
    "maxConcurrent": 1,
    "subagents": {
      "maxConcurrent": 1
    }
  }
}
```

- 메인 에이전트 동시 요청: **1개** (완전 순차 처리)
- 서브에이전트 동시 요청: **1개**

### 2. 토큰 및 시간 제한 (Token & Timeout Limits) ✅
**파일:** `/home/san/.openclaw/openclaw.json`

```json
"agents": {
  "defaults": {
    "model": {
      "timeoutSeconds": 30,
      "maxTokens": 512
    }
  }
}
```

- 모델 호출 타임아웃: **30초**
- 최대 응답 토큰: **512개** (하드캡)

### 3. 요청 속도 제한 (Rate Limiting) ✅
**파일:** `/home/san/.openclaw/workspace/config/rate-limiter.yml`

```yaml
rateLimiter:
  enabled: true
  debounceMs: 500                    # 인바운드 디바운스 500ms
  responseDelay:
    min: 300                         # 응답 지연 최소 300ms
    max: 800                         # 응답 지연 최대 800ms
  queue:
    maxSize: 5                       # 큐 최대 5개
    dropWhenFull: true               # 초과 시 새 요청 버림
```

### 4. TPM 자동 보호 (Model-Specific Token Per Minute Protection) ✅
**스크립트:** `/home/san/.openclaw/workspace/scripts/tpm_monitor.sh`
**Cron:** 매 1분마다 실행

```bash
* * * * * /home/san/.openclaw/workspace/scripts/tpm_monitor.sh
```

기능:
- **체크 주기:** 1분마다
- **모델별 한도:**
  - **Kimi K2.5:** 1,900,000 TPM (190만)
  - **Gemini, ChatGPT:** 800,000 TPM (80만)
- **쿨다운:** 30초 자동 시작
- **쿨다운 중:** 모든 신규 요청 차단

상태 확인:
```bash
cat /tmp/openclaw-tpm-state.json
```

## 파일 위치 요약

| 설정 항목 | 파일 경로 |
|-----------|-----------|
| 동시 처리 제한 | `/home/san/.openclaw/openclaw.json` |
| 토큰/타임아웃 제한 | `/home/san/.openclaw/openclaw.json` |
| 요청 속도 제한 | `/home/san/.openclaw/workspace/config/rate-limiter.yml` |
| TPM 모니터링 스크립트 | `/home/san/.openclaw/workspace/scripts/tpm_monitor.sh` |
| TPM 상태 파일 | `/tmp/openclaw-tpm-state.json` |
| TPM 로그 | `/tmp/openclaw-tpm.log` |

## 상태 확인 명령어

```bash
# 게이트웨이 상태 확인
systemctl --user status openclaw-gateway.service

# TPM 상태 확인
cat /tmp/openclaw-tpm-state.json

# 최근 TPM 로그 확인
tail -f /tmp/openclaw-tpm.log

# cron 작업 확인
crontab -l
```

## 설정 변경 방법

1. **동시 처리 제한 변경:**
   `/home/san/.openclaw/openclaw.json`의 `maxConcurrent` 값 수정

2. **요청 속도 제한 변경:**
   `/home/san/.openclaw/workspace/config/rate-limiter.yml` 수정

3. **TPM 한도 변경:**
   `/home/san/.openclaw/workspace/scripts/tpm_monitor.sh`의 `MAX_TPM` 변수 수정

모든 변경 후:
```bash
openclaw gateway restart
```
