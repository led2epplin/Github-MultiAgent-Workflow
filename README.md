# Github-MultiAgent-Workflow

여러 AI 에이전트가 **한 git 저장소를 유일한 상태로 삼아** 일하게 하는 작업 엔진. 사람이 쓰는 인수인계 문서가 없고, 작업자는 티켓 1장만 읽고, 완료는 검사기가 판정한다. 도구(GitHub Actions·태블릿·VPS)와 에이전트 벤더에 종속되지 않는다 — 엔진은 **역할**(오케스트레이터·작업자·검수자·최종 리뷰어)로만 쓰고, 벤더별 실행 방법은 어댑터(`adapters/`)가, 저장소 고유값(이름·창구·역할표·비밀 이름)은 소비 저장소의 매니페스트 `.mawf.yaml` 이 맡는다.

```
요구(Issue/채팅) → 오케스트레이터가 tickets/open/T-xxxxxx.yaml 커밋
   → 러너(Actions cron · 로컬)가 build/run_ticket.sh
      : 역할표 확인 → ready 티켓 claim(main, push 성공 = 선점) → 브랜치 → 작업자 실행기(.mawf/runner, 티켓마다 새 세션) → build/validate → PR
   → 검수자(작업자와 다른 계열)가 「오류 n / 권고 m / 확인 k」 → 오케스트레이터 병합·done
```

공통 운용 규칙 — 역할 배정(사용자 합의), 지시 권한·회신 형식, 세션 이름, 다중 세션(선점·임대·인계·멱등), 결함 = 티켓 + 재현 TC, 교차 검수, 매니페스트 — 은 [`engine/WORKFLOW.md`](engine/WORKFLOW.md). 소비 저장소에는 `.mawf/WORKFLOW.md` 로 동기화된다.

## 5분 설치
```bash
curl -sL https://raw.githubusercontent.com/led2epplin/Github-MultiAgent-Workflow/main/install.sh | bash -s -- /path/to/your-repo v1.1.0
cd /path/to/your-repo && git add -A && git commit -m "engine v1.1.0"
```
첫 줄에 「역할 미정 — 사용자와 역할표 확정 필요」가 뜬다. 역할표가 확정되기 전에는 하니스가 아무것도 claim 하지 않는다. 그다음 프로젝트 쪽에서 채우는 것(엔진 갱신이 건드리지 않는 파일):
1. `.mawf.yaml` — `roles:`(사용자와 합의한 역할표, `confirmed:` 한 줄), `runner.adapter`(예: `claude-code`)·`runner.token_secret`(저장소 비밀 이름)·`runner.git_name`. 모양은 [`engine/.mawf.example.yaml`](engine/.mawf.example.yaml)
2. `CLAUDE.md` 머리의 프로젝트 이름, `domain/RULES.md` 내용 규칙, `domain/schemas/` 산출물 템플릿
3. `domain/validate.py` — 산출물 검사(완료 판정의 본체). 예시가 들어 있다
4. `AGENTS.md` Code Review Rules — 검수자용 검사식
5. GitHub 쪽: Secrets 에 `runner.token_secret` 이름으로 작업자 토큰, Settings→Actions→General 에서 Workflow permissions *Read and write* + *Allow GitHub Actions to create and approve pull requests*

## 갱신 = 매니페스트 동기화
```yaml
# .mawf.yaml
engine: {repo: led2epplin/Github-MultiAgent-Workflow, ref: v1.1.0}
mode: full          # full = build/·.claude/·워크플로·.mawf/ 갱신 / docs = .mawf/WORKFLOW.md 만(코드가 없는 저장소)
```
`python3 build/engine_sync`(docs 모드는 `python3 .mawf/engine_sync`). 엔진이 아직 없는 저장소(1.0.x 포함)의 첫 동기화는 그 저장소 폴더에서 `python3 <엔진 checkout>/engine/build/engine_sync`. ref 가 현재 `ENGINE_VERSION` 과 같으면 아무것도 안 하고(ref 가 40자 커밋 해시면 — 태그 없이 판 고정 — 마지막으로 받은 커밋 `.mawf/ENGINE_REF` 와 비교), 엔진 저장소에 닿지 못하면(클라우드 프록시 등) 에러 대신 「저장소를 붙인 뒤 다시 실행」 한 줄. SessionStart 훅(`build/session_start`)이 대화형 세션마다 30초 상한으로 부르고, 하니스는 티켓 루프 전에 한 번 부른다.

## 원칙 (지키게 만드는 장치)
| 원칙 | 장치 |
|---|---|
| 상태는 산출물 안에 | 티켓 = `tickets/<상태>/` 파일, STATUS.md 자동 생성, 대화에 상태 없음 |
| 작업 단위는 작다 | 티켓 1장 = 산출물 1~2개, 읽기 상한 `limits.read_kb`(실행 대상 open·doing 에서 넘으면 validate 오류), `build/extract` |
| 인수인계는 생성한다 | `build/status`, SessionStart 훅이 STATUS·티켓·lessons 주입, 기동 프롬프트 고정(`CLAUDE.md`) |
| 자기 검수 금지 | 작업자 ≠ 검수자, 검수 입력 = 산출물 + 검사식뿐 |
| 완료는 하니스가 판정 | `build/validate` 통과 + 검수 오류 0 일 때만 병합. 반려 3회 → stranded |
| 결함은 티켓 + TC | `type: defect` + `tc:` 필수, validate 가 TC 실행, `tk resolve`(→ review) · `tk close`(TC 재실행 → done) |
| 범위 밖 금지 | PreToolUse 훅이 `outputs:` 밖 쓰기 차단. 발견한 일은 `discovered:` 로 새 티켓 |
| 역할 배정은 사용자 합의 | `.mawf.yaml roles` 가 비면 하니스 claim 없음 |
| 버전은 한 곳 | 태그 = `ENGINE_VERSION` = 매니페스트 ref |

## 티켓
```yaml
id: T-a1b2c3   type: card   title: …   goal: …   issue: "#12"   priority: 2
inputs: [legacy/x.json#05, domain/schemas/doc.md]     # 읽어도 되는 것(합계 ≤ read_kb)
outputs: [docs/DOC-001.md]                              # 써도 되는 것(훅이 강제)
dod: [schema]   limits: {read_kb: 60, max_turns: 40, lease_min: 90}
blocked_by: []  discovered_from: ""  claim: {by, at, lease_until}  pr: ""  rejected: 0  notes: ""
runner: ""      # 비우면 아무 실행 세션이나, 값이 있으면 그 이름으로 시작하는 HARNESS_RUNNER 만 집는다
tc: ""          # type defect 는 필수 — 결함이면 비영 종료하는 재현 TC
```
`build/tk new|claim|renew|move|reject|done|resolve|close|reopen|set|show`(결함은 `tk new --type defect --tc <TC> --assignee <오케스트레이터 역할>` — WORKFLOW §5), `build/ready [--one]`. 상태 전이는 디렉터리 이동이고 커밋이 곧 메시지다.

## 러너
- **GitHub Actions(기본)**: `.github/workflows/harness.yml` — push·30분 cron·수동 실행, `concurrency: harness`. 매 실행이 새 우분투라 clone → 동기화 → 역할표 확인 → 실행기 준비(어댑터 `setup.sh`) → 루프 → push.
- **로컬**: `HARNESS_RUNNER=<세션 이름> bash build/run_ticket.sh`(작업자 CLI·gh 로그인 필요). `DRY_RUN=1 NO_PR=1` 이면 실행기 없이 `domain/smoke.py` 로 루프만 검증.
- 여러 러너·세션이 같은 티켓을 집는 경합은 claim 커밋 push 성공 여부로 git 이 판정한다(진 쪽은 되돌리고 다음 장).
- 작업자 실행기 계약(`WORKFLOW.md` §8): `<실행기> <티켓>`, 종료 75 = 실행기 장애(반려로 세지 않음). 벤더별 구현은 `adapters/<이름>/`(지금: `claude-code`).

## 시험
`bash tests/run_all.sh <임시폴더> [대상 엔진 저장소]` — 결함 TC(`tests/defects/`) + 동기화·결함 티켓·claim·고유값 시험. 외부 접속 없음. 결함 기록은 `defects/D-NNNN.md`.

## 조사 근거(요약)
beads(에이전트용 이슈 트래커: ready 큐·의존관계·discovered-from), OpenSpec(변경 단위 폴더), Ralph 루프(완료는 하니스가 판정·컨텍스트는 버림), 에이전트 서브에이전트/팀, worktree 순차 병합·다중 모델 리뷰. 상세는 `docs/DESIGN.md`.

라이선스: MIT
