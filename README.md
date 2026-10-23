# Github-MultiAgent-Workflow

여러 AI 에이전트(Claude Code · Codex · 서브에이전트)가 **한 git 저장소를 유일한 상태로 삼아** 일하게 하는 작업 엔진. 사람이 쓰는 인수인계 문서가 없고, 에이전트는 티켓 1장만 읽고, 완료는 검사기가 판정한다. 도구(GitHub Actions·태블릿·VPS)에 종속되지 않는다 — 어디서 돌려도 같은 스크립트다.

```
요구(Issue/채팅) → 오케스트레이터가 tickets/open/T-xxxxxx.yaml 커밋
   → 러너(Actions cron · 로컬)가 build/run_ticket.sh
      : ready 티켓 claim(main) → 브랜치 → claude -p "/work T"(티켓마다 새 세션) → build/validate → PR
   → 검수자(Codex PR 리뷰 / 검수 에이전트)가 「오류 n / 권고 m / 확인 k」 → 오케스트레이터 병합·done
```

## 5분 설치
```bash
curl -sL https://raw.githubusercontent.com/led2epplin/Github-MultiAgent-Workflow/main/install.sh | bash -s -- /path/to/your-repo v1.0.0
cd /path/to/your-repo && git add -A && git commit -m "engine v1.0.0"
```
그다음 프로젝트 쪽에서 채우는 것(엔진 갱신이 건드리지 않는 파일):
1. `CLAUDE.md` 머리의 프로젝트 이름, `domain/RULES.md` 내용 규칙, `domain/schemas/` 산출물 템플릿
2. `domain/validate.py` — 산출물 검사(완료 판정의 본체). 예시가 들어 있다
3. `AGENTS.md` Code Review Rules — 검수자(Codex)용 검사식
4. GitHub 쪽: Secrets `CLAUDE_CODE_OAUTH_TOKEN`(`claude setup-token`), Settings→Actions→General 에서 Workflow permissions *Read and write* + *Allow GitHub Actions to create and approve pull requests*

갱신: `bash install.sh /path/to/your-repo v1.1.0` — `build/`·`.claude/settings.json`·`skills/work,review`·워크플로만 바뀌고 `ENGINE_VERSION` 이 찍힌다.

## 원칙 (지키게 만드는 장치)
| 원칙 | 장치 |
|---|---|
| 상태는 산출물 안에 | 티켓 = `tickets/<상태>/` 파일, STATUS.md 자동 생성, 대화에 상태 없음 |
| 작업 단위는 작다 | 티켓 1장 = 산출물 1~2개, 읽기 상한 `limits.read_kb`, `build/extract` |
| 인수인계는 생성한다 | `build/status`, SessionStart 훅이 STATUS·티켓·lessons 주입, 기동 프롬프트 고정(`CLAUDE.md`) |
| 자기 검수 금지 | 작업자 ≠ 검수자, 검수 입력 = 산출물 + 검사식뿐 |
| 완료는 하니스가 판정 | `build/validate` 통과 + 검수 오류 0 일 때만 병합. 반려 3회 → stranded |
| 범위 밖 금지 | PreToolUse 훅이 `outputs:` 밖 쓰기 차단. 발견한 일은 `discovered:` 로 새 티켓 |
| 버전은 한 곳 | 태그 = `VERSION` = 배포 파일명 |

## 티켓
```yaml
id: T-a1b2c3   type: card   title: …   goal: …   issue: "#12"   priority: 2
inputs: [legacy/x.json#05, domain/schemas/doc.md]     # 읽어도 되는 것(합계 ≤ read_kb)
outputs: [docs/DOC-001.md]                              # 써도 되는 것(훅이 강제)
dod: [schema]   limits: {read_kb: 60, max_turns: 40}
blocked_by: []  discovered_from: ""  claim: {by, at}  pr: ""  rejected: 0  notes: ""
```
`build/tk new|claim|move|reject|done|set|show`, `build/ready [--one]`. 상태 전이는 디렉터리 이동이고 커밋이 곧 메시지다.

## 러너
- **GitHub Actions(기본)**: `.github/workflows/harness.yml` — 10분 cron + 수동 실행, `concurrency: harness`. 매 실행이 새 우분투라 clone → 루프(시간 예산 내 여러 티켓) → push.
- **로컬**: `HARNESS_RUNNER=my-box bash build/run_ticket.sh` (claude·gh 로그인 필요). `DRY_RUN=1 NO_PR=1` 이면 claude 없이 `domain/smoke.py` 로 루프만 검증.
- 두 러너가 같은 티켓을 집는 경합은 claim 커밋 push 성공 여부로 git 이 판정한다.

## 조사 근거(요약)
beads(에이전트용 이슈 트래커: ready 큐·의존관계·discovered-from), OpenSpec(변경 단위 폴더), Ralph 루프(완료는 하니스가 판정·컨텍스트는 버림), Claude Code 서브에이전트/팀, worktree 순차 병합·다중 모델 리뷰. 상세는 `docs/DESIGN.md`.

라이선스: MIT
