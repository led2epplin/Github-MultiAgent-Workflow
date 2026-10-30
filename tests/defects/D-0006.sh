#!/usr/bin/env bash
# D-0006 해시 ref 에서 full·docs 가 같은 .mawf/ENGINE_REF 를 써서 full 파일을 갱신하지 않음 — docs 로 받은 기록이
#   full 소유 파일(build/ 등)까지 최신으로 판정한다(PR #2 Codex 리뷰).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0006.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0006 해시 ref — 다른 모드로 받은 기록은 최신이 아님: full(A) → docs(B) → full(B) 에서 build/tk = B"
show() { echo '```'; sed "s#$W#<임시폴더>#g; s/^/  /" "$1"; echo '```'; }
engine_remote "$W/eng"; A=$(git -C "$W/eng" rev-parse HEAD)
echo "# 판 B(시험)" >> "$W/eng/engine/build/tk"; git -C "$W/eng" commit -qam "판 B"; B=$(git -C "$W/eng" rev-parse HEAD)   # full 이 소유하는 파일만 바뀐 판
git clone -q --bare "$W/eng" "$W/eng.git"
git -C "$W/eng" show "$A:engine/build/tk" > "$W/tk.A"; git -C "$W/eng" show "$B:engine/build/tk" > "$W/tk.B"
C="$W/c"; consumer "$C"
step() {  # step <ref> <mode> <engine_sync 경로> <이름>
  manifest "$C" "$W/eng.git" "$1" "$2" 'roles: {mode: open-channel}'
  (cd "$C" && python3 "$3") > "$W/$4.out" 2>&1; echo "$4 — $2(${1:0:12}):"; show "$W/$4.out"
}
step "$A" full "$W/eng/engine/build/engine_sync" s1
expect "full(A) — build/tk = A 판" cmp -s "$W/tk.A" "$C/build/tk"
step "$B" docs build/engine_sync s2
expect "docs(B) — build/tk 는 아직 A(docs 는 build/ 를 받지 않음)" cmp -s "$W/tk.A" "$C/build/tk"
step "$B" full build/engine_sync s3
expect_nogrep "full(B) — 「변경 없음」 아님" '변경 없음' "$W/s3.out"
expect "full(B) — build/tk = B 판" cmp -s "$W/tk.B" "$C/build/tk"
expect_eq "full(B) — 기록 = 「B full」" "$B full" "$(cat "$C/.mawf/ENGINE_REF" 2>/dev/null)"
step "$B" full build/engine_sync s4
expect_grep "full(B) 재실행 — 「변경 없음」" '변경 없음' "$W/s4.out"
finish
