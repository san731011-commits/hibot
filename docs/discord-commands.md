# Discord/OpenClaw 명령 포맷 (3번)

OpenClaw가 메시지를 받아 이 스크립트를 호출하면 GitHub 이슈를 제어할 수 있습니다.

## 브리지 스크립트
- 파일: `scripts/openclaw_github_bridge.py`
- 입력: 명령 문자열 1개

## 지원 명령
1. 작업 생성
```bash
python3 scripts/openclaw_github_bridge.py "/task 로그인 오류 수정 | 로그인 실패 문구를 한국어로 통일 | P1 - 높음"
```

2. 상태 확인
```bash
python3 scripts/openclaw_github_bridge.py "/status #12"
```

3. 작업 취소
```bash
python3 scripts/openclaw_github_bridge.py "/cancel #12"
```

## OpenClaw 연결 예시
- Discord 메시지를 받으면 그대로 `message` 인자로 전달
- 출력 문자열을 Discord 채널로 다시 전송

예시 응답:
- `작업 이슈 생성 완료: #13 https://github.com/.../issues/13`
- `이슈 #12 상태: open ...`
