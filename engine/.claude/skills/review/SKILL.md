---
name: review
description: 검수자용. PR 또는 티켓의 산출물을 AGENTS.md 검사식으로 검수해 reviews/<ID>.md 에 「오류 n / 권고 m / 확인 k」를 쓴다. Codex 가 없을 때의 대체 검수자.
---

# /review <티켓ID>

- 입력은 티켓 `outputs:` 파일 + `AGENTS.md` 의 Code Review Rules + `sources/` 캐시뿐이다. 작업자의 `notes:`·대화·추측은 근거로 쓰지 않는다.
- 고치지 않는다. 지적만 한다.
- `reviews/<ID>.md` 에 AGENTS.md 의 출력 형식 그대로 쓴다: 첫 줄 `오류 n / 권고 m / 확인 k`, 이후 건별 `파일:줄 — 원문 인용`.
- 원문 대조는 글자 단위다. 「뜻이 같다」는 통과가 아니다.
- 총평·칭찬·요약을 쓰지 않는다.
