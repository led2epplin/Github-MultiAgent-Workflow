#!/usr/bin/env bash
# D-0009 해시 ref 에서 소스 경로에 공백이 있으면 정상 checkout 을 「확인 불가」로 거절 — `git rev-parse --show-toplevel HEAD`
#   출력을 공백으로 나눠 경로가 여러 조각이 된다(PR #2 Codex 재리뷰).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0009.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0009 해시 ref — 공백이 든 경로(받아 둔 checkout·엔진 원격·임시 폴더)에서도 동기화 성공"
show() { echo '```'; sed "s#$W#<임시폴더>#g; s/^/  /" "$1"; echo '```'; }
engine_remote "$W/eng"; A=$(git -C "$W/eng" rev-parse HEAD)
git clone -q "$W/eng" "$W/eng co"; git clone -q --bare "$W/eng" "$W/eng bare.git"; mkdir -p "$W/tmp dir"
SYNC="$W/eng/engine/build/engine_sync"
case_() {  # case_ <이름> <engine.repo> [MAWF_ENGINE_SRC]
  local C="$W/c-$1"; consumer "$C"; manifest "$C" "$2" "$A" docs 'roles: {mode: open-channel}'
  if [ -n "${3:-}" ]; then (cd "$C" && MAWF_ENGINE_SRC=$3 TMPDIR="$W/tmp dir" python3 "$SYNC") > "$W/$1.out" 2>&1
  else (cd "$C" && TMPDIR="$W/tmp dir" python3 "$SYNC") > "$W/$1.out" 2>&1; fi
  echo "$1 — ref A(${A:0:12}):"; show "$W/$1.out"
  expect_nogrep "$1 — 「동기화 실패」 없음" '동기화 실패' "$W/$1.out"
  expect "$1 — .mawf/WORKFLOW.md = 엔진 판" cmp -s "$W/eng/engine/WORKFLOW.md" "$C/.mawf/WORKFLOW.md"
  expect_eq "$1 — 기록 = 「A docs」" "$A docs" "$(cat "$C/.mawf/ENGINE_REF" 2>/dev/null)"
}
case_ src-space "$W/eng bare.git" "$W/eng co"     # MAWF_ENGINE_SRC = 공백 경로의 checkout
case_ repo-space "$W/eng bare.git"                # engine.repo = 공백 경로의 bare 원격, 임시 폴더도 공백
finish
