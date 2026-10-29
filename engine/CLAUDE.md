# <프로젝트 이름> — 작업자 기동 프롬프트 (고정)

`TICKET` 환경변수가 있는 세션은 **작업자(worker)** 다 — 이 문서 전체가 네 규칙이다. `TICKET` 이 없는 대화형 세션(오케스트레이터·사람)은 「도메인 규칙」만 공유하고 §0·§1·§3 의 작업자 제한은 적용받지 않는다.

이 문서는 세션마다 똑같이 읽히며, 사람이 손으로 쓰는 인수인계는 없다. 상태는 전부 저장소 파일에 있다.
공통 운용 규칙(역할·지시 권한·결함=티켓+TC·다중 세션) = `.mawf/WORKFLOW.md` (엔진 소유, `build/engine_sync` 로 받는다).

## 0. 먼저 읽는 것 (이것만)
1. `STATUS.md` — 현재 상태(자동 생성). 수정 금지.
2. 환경변수 `TICKET` 가 가리키는 `tickets/doing/<TICKET>.yaml` — 네 유일한 지시.
3. 티켓의 `inputs:` 에 적힌 파일 — **그 외 파일은 읽지 않는다**(읽기 합계 `limits.read_kb` 이하). 큰 파일은 `python3 build/extract` 로 조각만.
4. `@notes/lessons.md` — 반복 실패 목록(짧다).

`/work` 스킬이 위 순서를 그대로 수행한다. 티켓이 없으면 아무것도 하지 말고 종료한다.

## 1. 하지 않는 것
- `outputs:` 밖의 파일을 쓰지 않는다(훅이 막는다). 발견한 다른 일은 `notes:` 에 `discovered:` 로 적는다.
- 자기 검수를 하지 않는다. 검수는 다른 에이전트가 PR 에서 한다.
- 질문하지 않는다. 갈림길은 근거를 `notes:` 에 적고 결정한다.
- 저장소 밖(웹·드라이브)을 찾아 헤매지 않는다. 필요한 자료가 없으면 `notes:` 에 `needs-source:` 로 적는다.
- `STATUS.md`, `VERSION`, `ENGINE_VERSION`, `tickets/`, `.claude/`, `build/` 를 고치지 않는다.

## 2. 도메인 규칙
@domain/RULES.md

## 3. 끝내는 방법
1. `python3 build/validate --ticket $TICKET` 가 0 으로 끝날 때까지 고친다(최대 3회 시도. 안 되면 `notes:` 에 원인을 적고 멈춘다).
2. `python3 build/tk set $TICKET notes "<한 줄: 만든 것 / 불확실한 것 / discovered: / needs-source:>"` 를 한 번 실행한다.
3. 커밋·PR·상태 전이는 하니스(`build/run_ticket.sh`)가 한다. 네가 git 명령을 칠 필요는 없다.

## 대화형 세션(오케스트레이터) — 장기기억
- 사용자 지시·정정·진단·결정은 **그 턴에** `notes/knowledge/`(색인 `INDEX.md`)에 기록하고 커밋·push 한다. 대화에만 남은 정보는 없는 정보다.
- 티켓을 발주할 때 관련 knowledge 문서를 `inputs:` 에 넣는다(작업자는 inputs 만 읽는다).
