---
name: work
description: 티켓 1장을 수행한다. 하니스가 `claude -p "/work T-xxxxxx"` 로 부른다. 인수 = 티켓 ID.
---

# /work <티켓ID>

1. `tickets/doing/<ID>.yaml` 을 읽는다(SessionStart 훅이 이미 보여 줬으면 다시 읽지 않는다). 없으면 「티켓 없음」 한 줄 쓰고 끝낸다.
2. `inputs:` 의 파일만 읽는다. `#05` 같은 선택자가 붙어 있으면 `python3 build/extract <file> '#05'` 로 조각만 본다. 합계가 `limits.read_kb` 를 넘기면 더 읽지 않고 `notes:` 에 적는다.
3. `domain/schemas/` 의 템플릿과 `domain/RULES.md` 를 따라 `outputs:` 파일을 쓴다. 다른 파일은 쓰지 않는다(훅이 막는다).
4. `python3 build/validate --ticket <ID>` 를 돌린다. 오류가 있으면 고치고 다시 돌린다(최대 3회). 그래도 남으면 `notes:` 에 원인을 적고 멈춘다.
5. 끝나기 전에 `python3 build/tk set <ID> notes "<한 줄: 만든 것 / 불확실한 것 / discovered: / needs-source:>"` 를 한 번만 실행한다.
6. 커밋·PR·상태 전이는 하지 않는다. 하니스가 한다. 질문하지 않는다 — 근거를 notes 에 적고 결정한다.
