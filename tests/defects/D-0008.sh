#!/usr/bin/env bash
# D-0008 해시 ref 인데 소스 checkout 의 작업 트리(미커밋 변경)를 설치 — MAWF_ENGINE_SRC 의 HEAD 만 ref 와 비교하고 파일은
#   작업 트리에서 복사해, 고정하지 않은 내용이 들어가고 ENGINE_REF 는 그 커밋으로 기록된다(PR #2 Codex 재리뷰).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0008.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0008 해시 ref — 받아 둔 checkout 이라도 그 커밋의 트리만 적용(미커밋 변경·다른 HEAD 무관)"
show() { echo '```'; sed "s#$W#<임시폴더>#g; s/^/  /" "$1"; echo '```'; }
engine_remote "$W/eng"; A=$(git -C "$W/eng" rev-parse HEAD)
echo "판 B(시험)" >> "$W/eng/engine/WORKFLOW.md"; git -C "$W/eng" commit -qam "판 B"; B=$(git -C "$W/eng" rev-parse HEAD)
git clone -q --bare "$W/eng" "$W/eng.git"; git -C "$W/eng" show "$A:engine/WORKFLOW.md" > "$W/wf.A"
git clone -q "$W/eng" "$W/eng-a"; git -C "$W/eng-a" checkout -q "$A"
echo "미커밋 변경(시험)" >> "$W/eng-a/engine/WORKFLOW.md"                                      # HEAD = A, 작업 트리는 A 가 아님
SYNC="$W/eng/engine/build/engine_sync"
case_() {  # case_ <이름> <MAWF_ENGINE_SRC>
  local C="$W/c-$1"; consumer "$C"; manifest "$C" "$W/eng.git" "$A" docs 'roles: {mode: open-channel}'
  (cd "$C" && MAWF_ENGINE_SRC=$2 python3 "$SYNC") > "$W/$1.out" 2>&1; echo "$1 — ref A(${A:0:12}):"; show "$W/$1.out"
  expect "$1 — .mawf/WORKFLOW.md = 커밋 A 의 내용" cmp -s "$W/wf.A" "$C/.mawf/WORKFLOW.md"
  expect_eq "$1 — 기록 = 「A docs」" "$A docs" "$(cat "$C/.mawf/ENGINE_REF" 2>/dev/null)"
}
case_ dirty "$W/eng-a"                          # HEAD = A + 미커밋 변경
case_ other-head "$W/eng"                       # HEAD = B(A 를 이력에 가짐)
expect_nogrep "dirty — 미커밋 변경이 설치되지 않음" '미커밋 변경' "$W/c-dirty/.mawf/WORKFLOW.md"
finish
