# OpenClaw -> HTTP 브리지 명령

Discord/OpenClaw 메시지를 HTTP 브리지 API로 전달하는 CLI입니다.

파일:
- `scripts/openclaw_http_bridge.py`

## 사전 조건
- `.worker.env`에 아래 값 설정
```env
BRIDGE_TOKEN=...
BRIDGE_BASE_URL=http://127.0.0.1:8787
```

## 명령 예시
1. 비동기 작업 접수
```bash
python3 scripts/openclaw_http_bridge.py "/task React 버튼 컴포넌트 만들어줘"
```

2. 작업 상태 조회
```bash
python3 scripts/openclaw_http_bridge.py "/status <job_id>"
```

3. 브리지 헬스 확인
```bash
python3 scripts/openclaw_http_bridge.py "/health"
```

4. 동기 테스트(개발용)
```bash
python3 scripts/openclaw_http_bridge.py "/taskwait 간단 테스트" --wait-sec 60
```

## OpenClaw 연결 방식
- Discord 메시지 본문을 그대로 이 스크립트의 `message` 인자로 전달
- STDOUT 문자열을 Discord에 그대로 회신
- 권장 플로우:
  - `/task ...` 응답으로 받은 `job_id`를 저장
  - 백그라운드에서 `/status <job_id>`를 주기적으로 조회
  - 완료 상태(`succeeded`/`failed`)면 최종 결과 전송
