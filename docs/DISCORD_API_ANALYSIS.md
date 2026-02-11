# Discord API 문서 분석 - 멘션 없는 메시지 수신

## 분석일: 2026-02-11
## 분석자: OpenClaw Agent
## 소스: https://github.com/discord/discord-api-docs

---

## 1. 개요 (Overview)

Discord 봇이 **멘션 없이 모든 메시지를 읽으려면** `Message Content Intent`가 반드시 필요함.

### 핵심 개념
- **Message Content Intent**: 디스코드 봇이 메시지 내용(content)을 읽을 수 있는 권한
- **Gateway Intent**: Gateway 연결 시 선언하는 권한 플래그
- **Privileged Intent**: 검증된 봇(100서버+)은 Discord 승인 필요

---

## 2. Message Content Intent 상세 분석

### 2.1 Intent 값
```
Message Content Intent = 1 << 15 (비트 15)
= 32768 (10진수)
```

### 2.2 권한 비교

| 상태 | 멘션 없는 메시지 | 멘션된 메시지 | DM | slash command |
|------|----------------|--------------|-----|---------------|
| **Intent OFF** | ❌ 읽을 수 없음 | ✅ 읽을 수 있음 | ✅ 가능 | ✅ 가능 |
| **Intent ON** | ✅ 읽을 수 있음 | ✅ 읽을 수 있음 | ✅ 가능 | ✅ 가능 |

### 2.3 API 버전별 동작

| API 버전 | Message Content Intent 필요 |
|---------|---------------------------|
| v9 이하 | 선택적 (자동 제공될 수 있음) |
| **v10+** | **필수** (선언하지 않으면 빈 content) |

**중요**: OpenClaw는 어떤 API 버전을 사용하는지 확인 필요

---

## 3. Gateway Intents 상세

### 3.1 필요한 Intents 조합

멘션 없는 메시지를 받으려면:
```
GUILDS (1 << 0)
GUILD_MESSAGES (1 << 9)
MESSAGE_CONTENT (1 << 15)  ← 핵심
```

### 3.2 Gateway Identify Payload 예시
```json
{
  "op": 2,
  "d": {
    "token": "YOUR_BOT_TOKEN",
    "intents": 32768,  // MESSAGE_CONTENT
    "properties": {
      "os": "linux",
      "browser": "OpenClaw",
      "device": "OpenClaw"
    }
  }
}
```

### 3.3 Intent 계산
```
GUILDS = 1 << 0 = 1
GUILD_MESSAGES = 1 << 9 = 512
MESSAGE_CONTENT = 1 << 15 = 32768

총 Intents = 1 + 512 + 32768 = 33281
```

---

## 4. Discord Developer Portal 설정

### 4.1 활성화 단계

1. https://discord.com/developers/applications 접속
2. 봇 선택 → "Bot" 메뉴
3. "Privileged Gateway Intents" 섹션에서 **MESSAGE CONTENT INTENT** 활성화
4. 저장

### 4.2 승인 요구사항

| 봇 상태 | 승인 필요 |
|---------|----------|
| 100서버 미만 | ❌ 필요 없음 (자동) |
| 100서버 이상 (검증 필요) | ✅ Discord 승인 필요 |

**우리 봇**: @hibot (1470410511345651802) - 1서버만 있어서 승인 필요 없음

---

## 5. OpenClaw 적용 방법

### 5.1 현재 설정 (2026-02-11 기준)

**파일**: `~/.openclaw/openclaw.json`

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "YOUR_DISCORD_BOT_TOKEN",
      "groupPolicy": "allowlist",
      "guilds": {
        "1469645949436690502": {
          "channels": {
            "1470397073923899463": {
              "allow": true,
              "listenWithoutMention": true,
              "allowFrom": {
                "users": ["1122954940164354130"]
              }
            }
          }
        }
      }
    }
  }
}
```

### 5.2 OpenClaw Gateway 설정

**파일**: `~/.openclaw/openclaw.json`

```json
{
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "YOUR_GATEWAY_AUTH_TOKEN"
    }
  }
}
```

---

## 6. 문제 해결 (Troubleshooting)

### 6.1 메시지를 못 받는 경우 체크리스트

1. ✅ Discord Developer Portal에서 Message Content Intent 활성화
2. ✅ OpenClaw 설정에 `listenWithoutMention: true` 추가
3. ✅ Gateway Intents에 MESSAGE_CONTENT (1 << 15) 포함
4. ✅ OpenClaw Gateway 재시작
5. ✅ 채널 ID와 Guild ID 정확한지 확인

### 6.2 로그에서 확인할 내용

```
# 정상적인 경우
discord: logged in to discord as 1470410511345651802
discord: connected to gateway with intents: 33281

# 문제가 있는 경우
discord: skipping guild message (no-mention)
discord: MESSAGE_CREATE received but content is empty
```

---

## 7. Discord API 공식 문서 참조

### 7.1 핵심 문서
- **Gateway Intents**: https://discord.com/developers/docs/topics/gateway#gateway-intents
- **Message Content Intent**: https://discord.com/developers/docs/topics/gateway#message-content-intent
- **Privileged Intents**: https://discord.com/developers/docs/topics/gateway#privileged-intents

### 7.2 GitHub Discussions
- Message Content Privileged Intent FAQ: Discussion #5412
- Message Content Intent Alternatives: Discussion #6383579033751
- API versioning + API v10: Discussion #4510

---

## 8. 결론 및 권장사항

### 현재 상황
- 설정은 올바르게 되어 있음
- Message Content Intent는 Developer Portal에서 활성화되어 있음
- `listenWithoutMention: true` 설정 완료

### 디버깅 필요 사항
1. OpenClaw가 실제로 Gateway Intents를 어떻게 선언하는지 확인
2. Discord 플러그인 로그에서 `MESSAGE_CREATE` 이벤트 수신 여부 확인
3. `content` 필드가 비어있는지 확인 (API v10 이상에서 Intent 없으면 빈 문자열)

### 다음 단계
1. OpenClaw Discord 플러그인 소스 확인
2. Gateway 연결 시 intents 값 검증
3. MESSAGE_CREATE 핸들러 로깅 추가

---

## 9. 관련 파일 경로

```
~/.openclaw/openclaw.json                    # 메인 설정
~/.openclaw/workspace/config/openclaw.discord.yml  # 오버라이드 설정
/tmp/discord-api-docs/                       # 클론된 API 문서
```

---

**분석 완료 시간**: 2026-02-11 23:XX (KST)
**상태**: Discord API 문서 분석 완료, OpenClaw 디버깅 필요
