# CHANGELOG

## 1.3.0 (2026-10-30)
결함 등록 주체·담당(ORDER-38, 사용자 2026-10-30 19:28 「결함은 검수자가 등록 — assignee 를 오케스트레이터로」).
- WORKFLOW §5: 결함은 **발견한 검수자**가 직접 등록(판정을 기다리지 않음), `assignee` = 오케스트레이터 **역할**(역할표의 역할, 세션 이름 아님) — 오케스트레이터가 배정·우선순위·마감 판정. 고칠 곳이 defect 로 쓸 수 없는 경로면 `type process` + `--dod tc` + `--tc`(제목 「[결함]」). `defects/D-NNNN.md` 머리말에도 `assignee`.
- `build/tk new --assignee <역할>` → 티켓 필드 `assignee`(`tk set <T> assignee <역할>` 로도).
- `build/validate`: 결함 티켓(type defect 또는 dod 에 tc)인데 `assignee` 가 비면 권고(done 제외).
- `tests/test_defect.sh`: assignee 기록·권고·process+dod tc·set 뒤 권고 사라짐·done 제외(단언 35).

## 1.2.1 (2026-10-30)
- D-0010 `validate --all` 이 review·done 티켓의 「inputs 합계 > read_kb」 를 오류로 셈 → read_kb(작업자가 실행할 때 읽는 한도) 초과는 실행 대상(open·doing)만 오류, 다시 실행될 수 있는 hold·stranded 는 권고, 끝난 review·done 은 검사하지 않는다. 소비 저장소가 동기화 전부터 done 티켓 오류로 `validate --all` 을 통과하지 못하던 것(ORDER-34).

## 1.2.0 (2026-10-30)
태그 없이 엔진 판 고정(ORDER-33) — 이 환경에서 태그 push·Releases API 가 막혀 매번 사용자가 웹에서 태그를 만들어야 했다.
- `engine.ref` 가 40자 커밋 해시면 `engine_sync` 가 `git clone --branch` 대신 `git init` + `git fetch --depth 1 <원격> <sha>` + `checkout FETCH_HEAD` 로 받는다. 받은 커밋을 확인해 `.mawf/ENGINE_REF` 에 적고, 다음 실행은 이것과 비교해 같으면 네트워크 없이 「변경 없음」. 갱신 안내의 버전은 그 판의 `ENGINE_VERSION`.
- 태그·브랜치 ref 는 그대로(엔진 버전 비교). 태그·브랜치로 다시 받으면 옛 `.mawf/ENGINE_REF` 는 지운다.
- PR #2 교차 검수(Codex) 결함 — 티켓 + TC:
  - D-0006 full·docs 가 같은 `ENGINE_REF` 를 써 full 파일 미갱신 → `ENGINE_REF` = 「<해시> <모드>」, 다른 모드 기록은 최신 아님.
  - D-0007 커밋을 확인할 수 없는 소스(git 이 아닌 사본·다른 저장소 안의 폴더)를 적용 → 받은 판의 커밋 = ref 일 때만 적용, 아니면 「동기화 실패 … 기존 파일 그대로」.
  - D-0008 해시 고정인데 `MAWF_ENGINE_SRC` checkout 의 미커밋 변경을 설치 → 그 checkout 에서 커밋만 로컬 fetch 해 적용(작업 트리·HEAD 무관).
  - D-0009 경로에 공백이 있으면 정상 checkout 을 거절 → 저장소 뿌리와 HEAD 를 따로 조회.
- `tests/test_sync.sh` §6 — 로컬 bare 원격에서 해시 ref 동기화(docs·full) · 같은 해시 재실행(원격 치움)은 「변경 없음」 · `--check` · 해시 바꾸면 다시 받음 · 태그 ref 는 기존대로. §7 확인 못 한 판 거절 · §8 full(A) → docs(B) → full(B). run_all 14개(D-0001~0009 + 시험 5) 실패 0.

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
