#!/usr/bin/env bash
# 작업자 실행기 — Claude Code CLI 비대화 실행(티켓마다 새 세션). 엔진 계약(engine/WORKFLOW.md §8):
#   runner.sh <티켓> · 환경 TICKET MAX_TURNS RUNS_DIR · 기록 RUNS_DIR/<티켓>.json · 종료 75 = 실행기 장애(사유 RUNS_DIR/<티켓>.runner_error)
# 토큰: MAWF_RUNNER_TOKEN(하니스가 저장소 비밀에서 넘김) → CLAUDE_CODE_OAUTH_TOKEN. 없으면 이미 로그인된 CLI 를 쓴다.
# 추가 허용 도구: .mawf.yaml runner.allowed_tools_extra
set -uo pipefail
T=${1:?티켓 ID}
ROOT=$(pwd); RUNS=${RUNS_DIR:-$ROOT/runs}; mkdir -p "$RUNS"
fail() { echo "$1" > "$RUNS/$T.runner_error"; echo "실행기 장애: $1"; exit 75; }
[ -n "${MAWF_RUNNER_TOKEN:-}" ] && export CLAUDE_CODE_OAUTH_TOKEN="$MAWF_RUNNER_TOKEN"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
command -v claude > /dev/null || fail "claude CLI 없음 — .mawf/runner/setup.sh(하니스) 또는 수동 설치"
# 비대화 실행은 신뢰 대화상자를 못 띄운다 → 이 폴더를 미리 신뢰 목록에(하니스·HARNESS_TRUST=1 일 때만)
if [ "${HARNESS_TRUST:-0}" = "1" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; then
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
fi
SYNC=build/engine_sync; [ -f "$SYNC" ] || SYNC=.mawf/engine_sync
EXTRA=$(python3 "$SYNC" --get runner.allowed_tools_extra 2>/dev/null || true)
TOOLS="Read,Write,Edit,Bash(python3 build/*),Bash(git status *),Bash(git diff *),Bash(ls *)${EXTRA:+,$EXTRA}"
TICKET="$T" claude -p "/work $T" \
  --permission-mode acceptEdits --permission-prompts none --max-turns "${MAX_TURNS:-40}" \
  --allowedTools "$TOOLS" \
  --output-format json > "$RUNS/$T.json" 2> "$RUNS/$T.err"; rc=$?
python3 - "$RUNS/$T.json" <<'PY' || true
import json, sys
try:
    d = json.load(open(sys.argv[1])); print(f"작업자 종료: turns={d.get('num_turns')} cost=${d.get('total_cost_usd', 0):.3f} dur={d.get('duration_ms', 0)//1000}s")
except Exception as e: print("작업 기록 json 읽기 실패:", e)
PY
# 인증 실패 등 API 오류 = 실행기 장애(티켓 탓 아님)
if python3 - "$RUNS/$T.json" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: sys.exit(1)
sys.exit(0 if (d.get("is_error") and (d.get("api_error_status") or d.get("terminal_reason") == "api_error")) else 1)
PY
then
  fail "$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('result','')[:200])" "$RUNS/$T.json" 2>/dev/null)"
fi
exit "$rc"
