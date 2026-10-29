# 어댑터 — Claude Code CLI 작업자 실행기

엔진 하니스(`build/run_ticket.sh`)는 벤더를 모른다. 작업자를 부르는 방법(CLI 명령·플래그·설치·토큰 변수)은 이 폴더가 맡는다 — 계약은 `engine/WORKFLOW.md` §8.

쓰는 법(소비 저장소 `.mawf.yaml`):
```yaml
runner:
  adapter: claude-code                       # build/engine_sync 가 이 폴더를 .mawf/runner/ 로 복사
  token_secret: CLAUDE_CODE_OAUTH_TOKEN      # 저장소 비밀 이름(생략하면 adapter.yaml 기본값)
  allowed_tools_extra: ""                    # 작업자에게 더 허용할 도구(쉼표)
```

| 파일 | 하는 일 |
|---|---|
| `adapter.yaml` | 기본 비밀 이름·node 버전 — 하니스가 `build/engine_sync --runner-cfg` 로 읽는다 |
| `setup.sh` | 일회용 러너에서 CLI 설치 + 토큰 형식 점검(값은 출력 안 함) |
| `runner.sh` | `runner.sh <티켓>` — 비대화 실행, `runs/<티켓>.json` 기록, 인증·API 오류면 종료 75 |

다른 벤더를 붙이려면 같은 세 파일을 가진 `adapters/<이름>/` 을 만들면 된다. 엔진 쪽은 고치지 않는다.
