#!/usr/bin/env bash
# D-0007 해시 ref 인데 커밋을 확인할 수 없는 소스(git 이 아닌 사본)를 적용 — engine.repo·MAWF_ENGINE_SRC 가 다른 커밋을 내보낸
#   폴더여도 그 파일을 설치하고 갱신 성공을 낸다(PR #2 Codex 리뷰).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0007.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0007 해시 ref — 커밋을 확인할 수 없는 소스는 적용하지 않고 기존 파일 그대로"
show() { echo '```'; sed "s#$W#<임시폴더>#g; s/^/  /" "$1"; echo '```'; }
engine_remote "$W/eng"; A=$(git -C "$W/eng" rev-parse HEAD)
echo "판 B(시험)" >> "$W/eng/engine/WORKFLOW.md"; git -C "$W/eng" commit -qam "판 B"; B=$(git -C "$W/eng" rev-parse HEAD)
git clone -q --bare "$W/eng" "$W/eng.git"
mkdir -p "$W/copy" "$W/outer/sub"; git -C "$W/eng" archive "$B" | tar -x -C "$W/copy"            # git 이 아닌 사본(판 B 의 파일)
git -C "$W/eng" archive "$B" | tar -x -C "$W/outer/sub"; git -C "$W/outer" init -q                # 다른 git 저장소 안의 폴더
git -C "$W/outer" add -A; git -C "$W/outer" commit -qm outer
SYNC="$W/eng/engine/build/engine_sync"
case_() {  # case_ <이름> <engine.repo> [MAWF_ENGINE_SRC]
  local C="$W/c-$1"; consumer "$C"; manifest "$C" "$2" "$A" docs 'roles: {mode: open-channel}'
  (cd "$C" && MAWF_ENGINE_SRC=${3:-} python3 "$SYNC") > "$W/$1.out" 2>&1; rc=$?      # 빈 값 = 쓰지 않음
  echo "$1 — ref A(${A:0:12}):"; show "$W/$1.out"
  expect_eq "$1 — exit 0" 0 "$rc"
  expect_grep "$1 — 「동기화 실패 … 기존 파일 그대로」" '동기화 실패 — .*기존 파일 그대로' "$W/$1.out"
  expect "$1 — 아무것도 쓰지 않음(.mawf 없음)" test ! -e "$C/.mawf"
}
case_ copy-repo "$W/copy"                       # engine.repo = git 이 아닌 사본
case_ copy-src "$W/eng.git" "$W/copy"           # MAWF_ENGINE_SRC = git 이 아닌 사본
case_ outer-repo "$W/outer/sub"                 # engine.repo = 다른 저장소(HEAD ≠ A) 안의 폴더
finish
