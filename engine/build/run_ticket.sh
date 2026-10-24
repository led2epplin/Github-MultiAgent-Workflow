#!/usr/bin/env bash
# 하니스 — ready 티켓을 한 장씩: claim(main) → 브랜치 → 작업자(claude -p, 티켓마다 새 세션) → validate → PR
# 완료 판정은 여기(validate·검수)가 한다. 작업자의 「완료」 선언은 상태를 바꾸지 못한다.
# 환경: HARNESS_RUNNER(기본 hostname) BUDGET_MIN(기본 50) DRY_RUN=1(claude 대신 domain/smoke.py) MAX_TICKETS(기본 20)
#       CLAUDE_CODE_OAUTH_TOKEN 또는 로그인된 claude. gh 로그인(또는 GH_TOKEN) — PR 생성용. NO_PR=1 이면 main 직접 커밋(스모크 전용)
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
HARNESS_RUNNER=${HARNESS_RUNNER:-$(hostname)}
BUDGET_MIN=${BUDGET_MIN:-50}
MAX_TICKETS=${MAX_TICKETS:-20}
MAIN=${MAIN_BRANCH:-main}
START=$(date +%s)
log() { echo "[$(date +%H:%M:%S)] $*"; }
trust_workspace() {   # 비대화 실행은 신뢰 대화상자를 못 띄운다 → 이 폴더를 미리 신뢰 목록에 넣는다(HARNESS_TRUST=1 일 때만)
  [ "${HARNESS_TRUST:-0}" = "1" ] || return 0
  python3 - "$ROOT" "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json" <<'PY'
import json, sys, os
root, cfg = sys.argv[1], sys.argv[2]
try: d = json.load(open(cfg, encoding="utf-8"))
except Exception: d = {}
d.setdefault("projects", {}).setdefault(root, {})["hasTrustDialogAccepted"] = True
os.makedirs(os.path.dirname(cfg), exist_ok=True)
json.dump(d, open(cfg, "w", encoding="utf-8"), indent=1)
print("trust:", root)
PY
}

sync_main() {   # main 최신화. 실패하면 하드 리셋(로컬 변경은 티켓 단위로 이미 push 됐거나 버려도 되는 것)
  git checkout -q "$MAIN" 2>/dev/null || true
  git fetch -q origin "$MAIN" 2>/dev/null && git reset -q --hard "origin/$MAIN" 2>/dev/null || true
}
push_main() {   # 작은 커밋을 main 에 올린다. 경합이면 rebase 후 1회 재시도
  git add -A && git commit -qm "$1" || return 0
  git push -q origin "$MAIN" && return 0
  git pull -q --rebase origin "$MAIN" && git push -q origin "$MAIN"
}
elapsed_min() { echo $(( ($(date +%s) - START) / 60 )); }

n=0
while [ "$n" -lt "$MAX_TICKETS" ]; do
  if [ "$(elapsed_min)" -ge "$BUDGET_MIN" ]; then log "시간 예산 ${BUDGET_MIN}분 소진 — 종료"; break; fi
  sync_main
  T=$(python3 build/ready --one) || { log "ready 없음 — 종료"; break; }
  log "티켓 $T 집음"
  # 1) claim 을 main 에 먼저 올려 다른 러너와의 경합을 git 이 판정하게 한다
  python3 build/tk claim "$T" "$HARNESS_RUNNER" || { log "claim 실패 — 다음"; continue; }
  if ! push_main "claim $T ($HARNESS_RUNNER)"; then
    log "claim push 거절(다른 러너가 먼저) — 되돌리고 다음"; sync_main; continue
  fi
  n=$((n+1))
  BR="t/$T"
  git checkout -q -B "$BR"
  # 2) 작업자 — 티켓마다 새 세션. 티켓·STATUS·lessons 는 SessionStart 훅이 주입한다
  mkdir -p runs
  trust_workspace
  if [ "${DRY_RUN:-0}" = "1" ]; then
    if [ -f domain/smoke.py ]; then TICKET="$T" python3 domain/smoke.py "$T" > "runs/$T.log" 2>&1; rc=$?; else echo "domain/smoke.py 없음" > "runs/$T.log"; rc=1; fi
  else
    MAXT=$(python3 -c "import yaml,sys;print((yaml.safe_load(open('tickets/doing/$T.yaml')).get('limits') or {}).get('max_turns',40))")
    TICKET="$T" claude -p "/work $T" \
      --permission-mode acceptEdits --permission-prompts none --max-turns "$MAXT" \
      --allowedTools "Read,Write,Edit,Bash(python3 build/*),Bash(git status *),Bash(git diff *),Bash(ls *)" \
      --output-format json > "runs/$T.json" 2> "runs/$T.err"; rc=$?
    python3 - "$T" <<'EOF' || true
import json,sys; t=sys.argv[1]
try:
    d=json.load(open(f"runs/{t}.json")); print(f"작업자 종료: turns={d.get('num_turns')} cost=${d.get('total_cost_usd',0):.3f} dur={d.get('duration_ms',0)//1000}s")
except Exception as e: print("runs json 읽기 실패:", e)
EOF
  fi
  log "작업자 rc=$rc"
  # 2b) 러너 장애(인증 실패 등 API 오류)는 티켓 탓이 아니다 → 반려 세지 않고 open 으로 되돌린 뒤 실패 종료
  if [ "${DRY_RUN:-0}" != "1" ] && python3 - "$T" <<'PY'
import json, sys
try: d = json.load(open(f"runs/{sys.argv[1]}.json"))
except Exception: sys.exit(1)
sys.exit(0 if (d.get("is_error") and (d.get("api_error_status") or d.get("terminal_reason") == "api_error")) else 1)
PY
  then
    ERRMSG=$(python3 -c "import json;print(json.load(open('runs/$T.json')).get('result','')[:200])" 2>/dev/null)
    log "러너 장애: $ERRMSG — 티켓 $T 되돌림(반려 아님), 실행 종료"
    git checkout -q "$MAIN" && sync_main && git branch -q -D "$BR" 2>/dev/null
    python3 build/tk move "$T" open && python3 build/tk set "$T" claim.by "" >/dev/null 2>&1 || true
    python3 build/tk set "$T" notes "[runner-fail $(date +%H:%M)] $ERRMSG"
    push_main "unclaim $T (runner failure)"
    echo "::error::러너 장애 — $ERRMSG"
    exit 2
  fi
  # 3) 검증 — 통과해야만 PR. 실패면 반려(3회면 좌초)
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
  if python3 build/validate --ticket "$T" > "runs/$T.validate" 2>&1; then
    log "validate 통과"
    git add -A; git add -f "runs/$T.json" "runs/$T.validate" 2>/dev/null; git commit -qm "work $T" || true   # runs/ 는 gitignore — PR 브랜치에만 증거로 싣는다
    if [ "${NO_PR:-0}" = "1" ]; then
      git checkout -q "$MAIN" && git merge -q --ff-only "$BR" && python3 build/tk move "$T" review && { [ -n "$WNOTES" ] && python3 build/tk set "$T" notes "[worker] $WNOTES"; push_main "review $T (no-pr)"; } ; git branch -q -D "$BR"
    else
      git push -q -f origin "$BR"
      TITLE=$(python3 -c "import yaml;print(yaml.safe_load(open('tickets/doing/$T.yaml'))['title'])")
      PR=$(gh pr create --base "$MAIN" --head "$BR" --title "$T: $TITLE" --body "티켓 $T — 검수자는 AGENTS.md 규칙으로 「오류 n / 권고 m / 확인 k」를 남겨 주세요. validate 통과분. runs/$T.validate 참고." 2>runs/$T.pr.err) \
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
    git checkout -q "$MAIN" && sync_main && git branch -q -D "$BR" 2>/dev/null
    python3 build/tk reject "$T" "validate 오류 ${REASON}건 ($HARNESS_RUNNER) — $(grep '^오류' "runs/$T.validate" | head -3 | tr '\n' ' ') | worker: ${WNOTES:0:300}"
    push_main "reject $T"
  fi
done
sync_main
python3 build/status > /dev/null && push_main "status" || true
log "처리 $n 장. 끝."
