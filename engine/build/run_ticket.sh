#!/usr/bin/env bash
# 하니스 — ready 티켓을 한 장씩: claim(main) → 브랜치 → 작업자(실행기, 티켓마다 새 세션) → validate → PR
# 완료 판정은 여기(validate·검수)가 한다. 작업자의 「완료」 선언은 상태를 바꾸지 못한다. 규칙: .mawf/WORKFLOW.md §4·§8
# 환경: HARNESS_RUNNER(기본 hostname — claim 에 남는 실행 세션 이름) BUDGET_MIN(기본 50) MAX_TICKETS(기본 20)
#       DRY_RUN=1(실행기 대신 domain/smoke.py) NO_PR=1(PR 없이 main 직접 — 스모크 전용) · gh 로그인(또는 GH_TOKEN) — PR 생성용
# 작업자 실행기: .mawf/runner.sh(프로젝트가 직접 둔 것) → 없으면 .mawf/runner/runner.sh(.mawf.yaml runner.adapter 를 동기화가 복사)
#   계약: <실행기> <티켓> · 환경 TICKET MAX_TURNS RUNS_DIR · 종료 75 = 실행기 장애(티켓 탓 아님 — 사유는 runs/<티켓>.runner_error)
# 역할표(.mawf.yaml roles)가 없거나 비면(또는 open-channel) 아무것도 claim 하지 않고 0 으로 끝난다(WORKFLOW.md §1).
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
HARNESS_RUNNER=${HARNESS_RUNNER:-$(hostname)}
BUDGET_MIN=${BUDGET_MIN:-50}
MAX_TICKETS=${MAX_TICKETS:-20}
MAIN=${MAIN_BRANCH:-main}
START=$(date +%s)
log() { echo "[$(date +%H:%M:%S)] $*"; }

# 0) 역할표 — 사용자 합의 전에는 발주·claim 하지 않는다
if [ -f build/engine_sync ]; then
  ROLES_LINE=$(python3 build/engine_sync --roles); rrc=$?
  if [ "$rrc" -ne 0 ]; then
    if [ "$rrc" -eq 4 ]; then log "대화 창구 저장소(roles: open-channel) — 하니스 claim 없음, 종료"; else log "${ROLES_LINE:-역할 미정} — 하니스 claim 없음, 종료"; fi
    exit 0
  fi
fi
# 1) 작업자 실행기 — 없으면 claim 전에 멈춘다(티켓을 잡아 두고 못 돌리는 일 방지)
RUNNER=""
for r in .mawf/runner.sh .mawf/runner/runner.sh; do [ -f "$r" ] && { RUNNER=$r; break; }; done
if [ "${DRY_RUN:-0}" != "1" ] && [ -z "$RUNNER" ]; then
  log "작업자 실행기 없음 — .mawf.yaml runner.adapter 를 정하고 python3 build/engine_sync, 또는 .mawf/runner.sh 를 둔다(WORKFLOW.md §8)"
  echo "::error::작업자 실행기 없음(.mawf/runner.sh · .mawf/runner/runner.sh)"
  exit 1
fi

sync_main() {   # main 최신화. 진행 중 rebase·merge 를 먼저 거두고, 실패하면 하드 리셋(로컬 변경은 티켓 단위로 이미 push 됐거나 버려도 되는 것)
  git rebase --abort 2>/dev/null; git merge --abort 2>/dev/null
  git checkout -q -f "$MAIN" 2>/dev/null || true
  git fetch -q origin "$MAIN" 2>/dev/null && git reset -q --hard "origin/$MAIN" 2>/dev/null || true
}
push_main() {   # 작은 커밋을 main 에 올린다. 경합이면 rebase 후 1회 재시도 — rebase 가 충돌하면 거두고 실패로
  git add -A && git commit -qm "$1" || return 0
  git push -q origin "$MAIN" && return 0
  if ! git pull -q --rebase origin "$MAIN"; then git rebase --abort 2>/dev/null; return 1; fi
  git push -q origin "$MAIN"
}
push_claim() {  # claim 커밋은 재시도하지 않는다 — 먼저 push 된 claim 만 산다(선점 = push 성공, WORKFLOW.md §4)
  git add -A && git commit -qm "$1" || return 1
  git push -q origin "$MAIN"
}
elapsed_min() { echo $(( ($(date +%s) - START) / 60 )); }

n=0
while [ "$n" -lt "$MAX_TICKETS" ]; do
  if [ "$(elapsed_min)" -ge "$BUDGET_MIN" ]; then log "시간 예산 ${BUDGET_MIN}분 소진 — 종료"; break; fi
  sync_main
  T=$(python3 build/ready --one) || { log "ready 없음 — 종료"; break; }
  log "티켓 $T 집음"
  # 2) claim 을 main 에 먼저 올려 다른 세션과의 경합을 git 이 판정하게 한다
  python3 build/tk claim "$T" "$HARNESS_RUNNER" || { log "claim 실패 — 다음"; continue; }
  if ! push_claim "claim $T ($HARNESS_RUNNER)"; then
    log "claim push 거절(다른 세션이 먼저) — 되돌리고 다음"; sync_main; continue
  fi
  n=$((n+1))
  BR="t/$T"
  git checkout -q -B "$BR"
  # 3) 작업자 — 티켓마다 새 세션. 티켓·STATUS·lessons 는 SessionStart 훅이 주입한다
  mkdir -p runs
  if [ "${DRY_RUN:-0}" = "1" ]; then
    if [ -f domain/smoke.py ]; then TICKET="$T" python3 domain/smoke.py "$T" > "runs/$T.log" 2>&1; rc=$?; else echo "domain/smoke.py 없음" > "runs/$T.log"; rc=1; fi
  else
    MAXT=$(python3 -c "import yaml,sys;print((yaml.safe_load(open('tickets/doing/$T.yaml')).get('limits') or {}).get('max_turns',40))")
    rm -f "runs/$T.runner_error"
    TICKET="$T" MAX_TURNS="$MAXT" RUNS_DIR="$ROOT/runs" bash "$RUNNER" "$T" > "runs/$T.log" 2>&1; rc=$?
    tail -3 "runs/$T.log" 2>/dev/null | sed 's/^/  │ /'
  fi
  log "작업자 rc=$rc"
  # 3b) 실행기 장애(인증 실패 등)는 티켓 탓이 아니다 → 반려 세지 않고 open 으로 되돌린 뒤 실패 종료
  if [ "${DRY_RUN:-0}" != "1" ] && [ "$rc" -eq 75 ]; then
    ERRMSG=$(head -c 200 "runs/$T.runner_error" 2>/dev/null || echo "사유 없음")
    log "실행기 장애: $ERRMSG — 티켓 $T 되돌림(반려 아님), 실행 종료"
    git checkout -q "$MAIN" && sync_main && git branch -q -D "$BR" 2>/dev/null
    python3 build/tk move "$T" open && python3 build/tk set "$T" claim.by "" >/dev/null 2>&1 || true
    python3 build/tk set "$T" notes "[runner-fail $(date +%H:%M) $HARNESS_RUNNER] $ERRMSG"
    push_main "unclaim $T (runner failure)"
    echo "::error::실행기 장애 — $ERRMSG"
    exit 2
  fi
  # 4) 검증 — 통과해야만 PR. 실패면 반려(3회면 좌초)
  # 작업자가 티켓 notes 에 적은 것(브랜치 사본)을 꺼내 둔다 — 티켓 정본은 main 이므로 브랜치에는 티켓 변경을 싣지 않는다
  WNOTES=$(python3 - "$T" <<'PY'
import yaml, sys, subprocess
t = sys.argv[1]
cur = (yaml.safe_load(open(f"tickets/doing/{t}.yaml", encoding="utf-8")) or {}).get("notes") or ""
try:
    base = subprocess.run(["git", "show", f"HEAD:tickets/doing/{t}.yaml"], capture_output=True, text=True).stdout
    base = (yaml.safe_load(base) or {}).get("notes") or ""
except Exception:
    base = ""
print(cur.replace(base, "", 1).strip())
PY
)
  git checkout -q -- tickets/ 2>/dev/null || true
  EVID=(); for f in "runs/$T.json" "runs/$T.log" "runs/$T.validate"; do [ -f "$f" ] && EVID+=("$f"); done
  if python3 build/validate --ticket "$T" > "runs/$T.validate" 2>&1; then
    log "validate 통과"
    EVID+=("runs/$T.validate")
    git add -A; git add -f "${EVID[@]}" 2>/dev/null; git commit -qm "work $T ($HARNESS_RUNNER)" || true   # runs/ 는 gitignore — PR 브랜치에만 증거로 싣는다
    if [ "${NO_PR:-0}" = "1" ]; then
      git checkout -q "$MAIN" && git merge -q --ff-only "$BR" && python3 build/tk move "$T" review && { [ -n "$WNOTES" ] && python3 build/tk set "$T" notes "[worker] $WNOTES"; push_main "review $T (no-pr)"; } ; git branch -q -D "$BR"
    else
      git push -q -f origin "$BR"
      TITLE=$(python3 -c "import yaml;print(yaml.safe_load(open('tickets/doing/$T.yaml'))['title'])")
      PR=$(gh pr create --base "$MAIN" --head "$BR" --title "$T: $TITLE" --body "티켓 $T — 검수자는 AGENTS.md 규칙으로 「오류 n / 권고 m / 확인 k」를 남겨 주세요. validate 통과분. runs/$T.validate 참고. 실행: $HARNESS_RUNNER" 2>runs/$T.pr.err) \
        || PR=$(gh pr list --head "$BR" --state open --json url -q '.[0].url' 2>/dev/null) \
        || PR="(pr 생성 실패: $(tail -c 200 runs/$T.pr.err))"
      [ -z "$PR" ] && PR="(pr 생성 실패: $(tail -c 200 runs/$T.pr.err))"
      log "PR: $PR"
      git checkout -q "$MAIN" && sync_main
      python3 build/tk set "$T" pr "$PR" && python3 build/tk move "$T" review
      [ -n "$WNOTES" ] && python3 build/tk set "$T" notes "[worker] $WNOTES"
      push_main "review $T → $PR"
    fi
  else
    log "validate 실패 — 반려"; head -20 "runs/$T.validate"
    REASON=$(grep -c '^오류' "runs/$T.validate" || true)
    # 반려돼도 작업물은 버리지 않는다 — rejected/<T>-<회차> 브랜치로 push 해 두고(검수·재작업 참고) main 에서는 티켓만 되돌린다
    N=$(python3 -c "import yaml;print(int((yaml.safe_load(open('tickets/doing/$T.yaml')).get('rejected') or 0)+1))" 2>/dev/null || echo 1)
    EVID+=("runs/$T.validate")
    git add -A; git add -f "${EVID[@]}" 2>/dev/null; git commit -qm "rejected work $T (#$N, $HARNESS_RUNNER)" || true
    git push -q -f origin "$BR:rejected/$T-$N" 2>/dev/null && log "작업물 보존: rejected/$T-$N" || true
    git checkout -q "$MAIN" && sync_main && git branch -q -D "$BR" 2>/dev/null
    python3 build/tk reject "$T" "validate 오류 ${REASON}건 ($HARNESS_RUNNER) — $(grep '^오류' "runs/$T.validate" | head -3 | tr '\n' ' ') | worker: ${WNOTES:0:300}"
    push_main "reject $T"
  fi
done
sync_main
python3 build/status > /dev/null && push_main "status" || true
log "처리 $n 장. 끝."
