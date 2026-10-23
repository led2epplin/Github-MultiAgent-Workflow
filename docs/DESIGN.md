# 설계 노트

## 왜 이렇게 만들었나 (지난 실패 → 장치)
| 실패 | 장치 |
|---|---|
| 세션·판본이 바뀔 때마다 사람이 handoff 작성 | STATUS·티켓 자동 생성, 기동 프롬프트 고정 |
| 에이전트가 큰 파일을 통째로 읽어 컨텍스트 폭발 | 산출물 1개 1파일, 티켓 읽기 상한, extract |
| 파일명 ≠ 내부 버전 | 태그 = VERSION = 파일명 |
| 날아간 턴·기억 밖 편집 | 모든 변경은 commit·티켓에, 대화에 상태를 두지 않음 |
| 자기 검수·검수 생략 | 역할 분리, 검수 없으면 병합 불가 |
| 「다 했다」는 선언 | 완료는 validate + 검수가 판정 |

## 조사해서 가져온 것 / 버린 것
| 방식 | 판단 | 이유 |
|---|---|---|
| beads (git 안의 이슈 트래커) | 모델 채택, 도구 보류 | ready 큐·관계·discovered-from·해시 ID 는 그대로. 도구는 Dolt·데몬 의존이라 여러 환경에 깔기 어려움 → 티켓=파일 |
| Spec Kit / OpenSpec | 순서·변경 단위 채택 | specify→plan→tasks→implement; 동결 뒤 변경은 `changes/<id>/` 폴더 |
| Ralph 루프 | 채택 | 완료는 하니스, 스펙 불변, 실패 로그 원문, 반복 상한 |
| Claude Code 에이전트 팀 | 보류 | 독립 작업엔 서브에이전트/별도 세션이면 충분. 「리드는 구현 금지」만 가져옴 |
| worktree·순차 병합·검증자·다중 모델 리뷰 | 채택 | 같은 프롬프트의 모델은 같은 맹점 → 검수자는 다른 계열 |
| Managed Agents | 보류 | 상태가 저장소에 있으면 하니스는 무엇이든 같음 |

## 러너 선택
요구는 연산이 아니라 「켜져 있음」이다. GitHub Actions 는 호출마다 새 우분투를 주고 상태는 push 로 남으므로 상시 서버가 필요 없다. 로컬(태블릿·PC)은 같은 스크립트로 수동·긴급·오프라인용. VPS 는 상주 서비스(웹훅·채점 API 중계)가 필요해질 때만.

## 에이전트 간 통신
없다. 저장소가 통신이다 — 티켓 파일 이동 커밋 = 「맡았다」, reviews/ = 「검수 결과」, STATUS.md = 「지금 상태」. 깨우는 신호만 cron·수동 실행·PR 이벤트가 맡는다. 에이전트가 에이전트를 멘션해 깨우는 구조는 루프·토큰 폭주 때문에 쓰지 않는다.

## 검수
- 작업자와 다른 모델 계열(예: Claude 작업 → Codex PR 리뷰).
- 입력은 산출물 + 검사식(AGENTS.md)뿐. 출력은 「오류 n / 권고 m / 확인 k」 + 건별 원문.
- 병합분 10% 무작위 재검수(검수자 편향 탐지).

## 출처
Tembo — Multi-Agent AI Coding Workflows (2026) · Better Stack — Beads · SSOJet — Spec-Driven Development Tools · OpenSpec · DreamHost — The Ralph Wiggum Loop · Addy Osmani — Claude Code Agent Teams · Claude Code docs (headless, GitHub Actions, env vars) · OpenAI Codex docs (non-interactive, GitHub code review)
