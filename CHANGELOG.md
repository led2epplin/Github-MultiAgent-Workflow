# CHANGELOG

## 1.2.0 (2026-10-30)
태그 없이 엔진 판 고정(ORDER-33) — 이 환경에서 태그 push·Releases API 가 막혀 매번 사용자가 웹에서 태그를 만들어야 했다.
- `engine.ref` 가 40자 커밋 해시면 `engine_sync` 가 `git clone --branch` 대신 `git init` + `git fetch --depth 1 <원격> <sha>` + `checkout FETCH_HEAD` 로 받는다. 받은 커밋을 확인해 `.mawf/ENGINE_REF` 에 적고, 다음 실행은 이것과 비교해 같으면 네트워크 없이 「변경 없음」. 갱신 안내의 버전은 그 판의 `ENGINE_VERSION`.
- 태그·브랜치 ref 는 그대로(엔진 버전 비교). 태그·브랜치로 다시 받으면 옛 `.mawf/ENGINE_REF` 는 지운다.
- `tests/test_sync.sh` §6 — 로컬 bare 원격에서 해시 ref 동기화(docs·full) · 같은 해시 재실행(원격 치움)은 「변경 없음」 · `--check` · 해시 바꾸면 다시 받음 · 태그 ref 는 기존대로.

## 1.1.1 (2026-10-30)
교차 검수(ORDER-30) P0 3건 — 결함 티켓 + TC(고치기 전 실패 · 고친 뒤 통과).
- D-0002 역할표 철회가 실행 중 하니스에 반영 안 됨 → `run_ticket.sh` 가 매 sync_main 뒤 역할표를 다시 본다(`roles_gate`).
- D-0003 임대 인계 뒤 이전 작업자가 결과를 확정 → claim 세대(`claim.by|claim.at`)를 결과 확정 전마다 원격과 대조, 실행 중 `renew_loop`(임대 절반마다 연장, 남이 인계하면 실행기 종료), 작업물은 `lost/<티켓>-<세션>-<세대>`.
- D-0003 보강(PR #1 교차 검수): 상태 전이 push 가 거절되면 rebase 재적용 대신 원격 최신 판에서 claim 을 다시 보고 전이를 다시 만든다(`fenced`), renew 용 임시 worktree 는 하니스가 지운다.
- D-0005 두 세션이 같은 작업 브랜치 `t/<T>` 를 -f 로 덮음 → 작업 브랜치 `t/<T>-<세션>-<claim.at 세대>`, `lost/` 도 같은 꼴. PR 은 그 브랜치로(재작업도 새 브랜치·새 PR).
- D-0004 defect 티켓이 close 검사 없이 done → `tk done`·`tk move … done` 은 defect 거절, `validate --all` 이 done defect 의 `fixed_in`·`reviewed_by` 검사.
- 루트 `AGENTS.md` 「Review guidelines」(PR 자동 리뷰용).

## 1.1.0 (2026-10-29)
공통 운용 규칙 `engine/WORKFLOW.md`(역할로만), 매니페스트 `.mawf.yaml` + `build/engine_sync`(full|docs), 결함 티켓(`type: defect` + tc), 역할표 게이트, claim 임대·인계·멱등, 벤더 중립 하니스(`adapters/claude-code`), D-0001(claim 경합 rebase 잔여).
