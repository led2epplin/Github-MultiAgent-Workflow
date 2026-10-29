#!/usr/bin/env bash
# Github-MultiAgent-Workflow 엔진 설치/갱신 (mode full). 보통은 소비 저장소에서 python3 build/engine_sync 가 이것을 부른다(.mawf.yaml 이 판을 고정).
#   로컬:  bash install.sh <대상저장소경로>
#   원격:  curl -sL https://raw.githubusercontent.com/led2epplin/Github-MultiAgent-Workflow/main/install.sh | bash -s -- <대상저장소경로> [태그|main]
# 덮어쓰는 것(엔진 소유): build/ (schemas/ticket.yaml·engine_sync 포함), .claude/settings.json, .claude/skills/work, .claude/skills/review,
#   .github/workflows/harness.yml·release.yml, .mawf/WORKFLOW.md, .mawf/runner/(.mawf.yaml runner.adapter 가 있을 때 — adapters/<이름>)
# 없을 때만 만드는 것(프로젝트 소유): .mawf.yaml(역할표는 비워 둠 — 사용자와 확정), CLAUDE.md, AGENTS.md, domain/, notes/, tickets/*, runs/, VERSION, STATUS.md, .gitignore
# 출력 첫 줄: 역할표가 없거나 비면 「역할 미정 — 사용자와 역할표 확정 필요」(.mawf/WORKFLOW.md §1)
set -euo pipefail
TARGET=${1:?대상 저장소 경로}
REF=${2:-main}
REPO_URL=${ENGINE_REPO:-https://github.com/led2epplin/Github-MultiAgent-Workflow}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")
if [ -n "$HERE" ] && [ -d "$HERE/engine" ]; then
  SRC="$HERE"
else
  TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
  git clone -q --depth 1 --branch "$REF" "$REPO_URL" "$TMP/engine-src"
  SRC="$TMP/engine-src"
fi
VER=$(cat "$SRC/ENGINE_VERSION")
mkdir -p "$TARGET"; cd "$TARGET"
# 엔진 소유(덮어씀)
mkdir -p build/schemas .claude/skills .github/workflows .mawf
cp -r "$SRC/engine/build/." build/
cp "$SRC/engine/.claude/settings.json" .claude/settings.json
rm -rf .claude/skills/work .claude/skills/review
cp -r "$SRC/engine/.claude/skills/work" "$SRC/engine/.claude/skills/review" .claude/skills/
cp "$SRC/engine/.github/workflows/harness.yml" .github/workflows/harness.yml
cp "$SRC/engine/.github/workflows/release.yml" .github/workflows/release.yml
cp "$SRC/engine/WORKFLOW.md" .mawf/WORKFLOW.md
chmod +x build/tk build/ready build/validate build/status build/session_start build/guard_write build/extract build/run_ticket.sh build/engine_sync 2>/dev/null || true
# 프로젝트 소유(없을 때만)
[ -f .mawf.yaml ] || sed "s|^  ref: .*|  ref: v$VER                                    # 태그 권장 — 현재 엔진 버전과 같으면 동기화는 아무것도 안 한다|" "$SRC/engine/.mawf.example.yaml" > .mawf.yaml
[ -f CLAUDE.md ] || cp "$SRC/engine/CLAUDE.md" CLAUDE.md
[ -f AGENTS.md ] || cp "$SRC/engine/AGENTS.md" AGENTS.md
[ -d domain ] || cp -r "$SRC/engine/domain" domain
[ -d notes ] || cp -r "$SRC/engine/notes" notes
for d in open hold doing review done stranded; do mkdir -p "tickets/$d"; [ -e "tickets/$d/.gitkeep" ] || touch "tickets/$d/.gitkeep"; done
mkdir -p runs; [ -e runs/.gitkeep ] || touch runs/.gitkeep
[ -f VERSION ] || echo "0.1.0-dev" > VERSION
[ -f .gitignore ] || printf 'cache/\nruns/\n__pycache__/\n*.pyc\n' > .gitignore
echo "$VER" > ENGINE_VERSION
# 작업자 실행기 어댑터(.mawf.yaml runner.adapter) — engine_sync 에서 불렸으면 그쪽이 복사한다
AD=$(python3 build/engine_sync --get runner.adapter 2>/dev/null || true)
if [ -z "${MAWF_FROM_SYNC:-}" ] && [ -n "$AD" ]; then
  if [ -d "$SRC/adapters/$AD" ]; then rm -rf .mawf/runner; cp -r "$SRC/adapters/$AD" .mawf/runner; echo "$AD" > .mawf/runner/ADAPTER; chmod +x .mawf/runner/*.sh 2>/dev/null || true
  else echo "경고: 어댑터 없음 adapters/$AD — .mawf.yaml runner.adapter 확인" >&2; fi
fi
python3 build/status > /dev/null 2>&1 || true
[ -n "${MAWF_FROM_SYNC:-}" ] || python3 build/engine_sync --roles || true   # 역할 미정이면 이 줄이 출력 첫 줄
echo "engine $VER → $TARGET  (갱신: .mawf.yaml engine.ref 를 바꾸고 python3 build/engine_sync)"
