#!/usr/bin/env bash
# 엔진 전체 자동검수 — 결함 TC(tests/defects/D-*.sh) 전부 + 시험(tests/test_*.sh) 전부. 하나라도 비영이면 비영 종료, 끝에 요약 표.
# 사용: bash tests/run_all.sh <비어 있는 임시 폴더> [대상 엔진 저장소]
set -u
SRC=$(cd "$(dirname "$0")/.." && pwd)
W=${1:?임시 작업 폴더}; TGT=${2:-}
rm -rf "$W"; mkdir -p "$W"
rows=(); fail=0; n=0
one() {
  local kind=$1 f=$2 name s rc note
  name=$(basename "$f" .sh); s=$(date +%s); n=$((n + 1))
  bash "$f" "$W/$name" ${TGT:+"$TGT"} > "$W/$name.md" 2> "$W/$name.err"; rc=$?
  note=$(grep -E '^단언: ' "$W/$name.md" | tail -1)
  [ "$rc" -eq 0 ] || fail=$((fail + 1))
  rows+=("| $name | $kind | $rc | $(( $(date +%s) - s )) | $([ "$rc" -eq 0 ] && echo 통과 || echo '**실패**') | ${note:--} |")
  echo "$name exit=$rc" >&2
}
for f in "$SRC"/tests/defects/D-*.sh; do [ -e "$f" ] && one TC "$f"; done
for f in "$SRC"/tests/test_*.sh; do one 시험 "$f"; done
echo "# 엔진 전체 자동검수 결과 (tests/run_all.sh)"
echo
echo "실행: $(date -u +%Y-%m-%dT%H:%M:%SZ) · $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$SRC" diff --quiet 2>/dev/null || echo '(+작업 트리)') · 엔진 $(cat "${TGT:-$SRC}/ENGINE_VERSION") · 결과 본문 <임시폴더>/<이름>.md"
echo
echo "| 이름 | 종류 | exit | 초 | 결과 | 단언 |"
echo "|---|---|---|---|---|---|"
printf '%s\n' "${rows[@]}"
echo
echo "= 실행 $n개 · 실패 $fail개"
[ "$fail" -eq 0 ]
