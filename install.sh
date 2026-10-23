#!/usr/bin/env bash
# Github-MultiAgent-Workflow 엔진 설치/갱신
#   로컬:  bash install.sh <대상저장소경로>
#   원격:  curl -sL https://raw.githubusercontent.com/led2epplin/Github-MultiAgent-Workflow/main/install.sh | bash -s -- <대상저장소경로> [태그|main]
# 덮어쓰는 것(엔진 소유): build/ (schemas/ticket.yaml 포함), .claude/settings.json, .claude/skills/work, .claude/skills/review, .github/workflows/harness.yml
# 없을 때만 만드는 것(프로젝트 소유): CLAUDE.md, AGENTS.md, domain/, notes/, tickets/*, runs/, VERSION, STATUS.md, .gitignore
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
mkdir -p build/schemas .claude/skills .github/workflows
cp -r "$SRC/engine/build/." build/
cp "$SRC/engine/.claude/settings.json" .claude/settings.json
rm -rf .claude/skills/work .claude/skills/review
cp -r "$SRC/engine/.claude/skills/work" "$SRC/engine/.claude/skills/review" .claude/skills/
cp "$SRC/engine/.github/workflows/harness.yml" .github/workflows/harness.yml
cp "$SRC/engine/.github/workflows/release.yml" .github/workflows/release.yml
chmod +x build/tk build/ready build/validate build/status build/session_start build/guard_write build/extract build/run_ticket.sh 2>/dev/null || true
# 프로젝트 소유(없을 때만)
[ -f CLAUDE.md ] || cp "$SRC/engine/CLAUDE.md" CLAUDE.md
[ -f AGENTS.md ] || cp "$SRC/engine/AGENTS.md" AGENTS.md
[ -d domain ] || cp -r "$SRC/engine/domain" domain
[ -d notes ] || cp -r "$SRC/engine/notes" notes
for d in open doing review done stranded; do mkdir -p "tickets/$d"; [ -e "tickets/$d/.gitkeep" ] || touch "tickets/$d/.gitkeep"; done
mkdir -p runs; [ -e runs/.gitkeep ] || touch runs/.gitkeep
[ -f VERSION ] || echo "0.1.0-dev" > VERSION
[ -f .gitignore ] || printf 'cache/\nruns/\n__pycache__/\n*.pyc\n' > .gitignore
echo "$VER" > ENGINE_VERSION
python3 build/status > /dev/null 2>&1 || true
echo "engine $VER → $TARGET  (갱신: bash install.sh $TARGET <태그>)"
