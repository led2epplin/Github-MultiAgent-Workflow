# 시험 단언 도우미 — 시험 스크립트가 source 한다. 기대값과 대조해 실패를 누적하고, finish 가 비영 종료로 전파한다.
#   expect "설명" <명령…>          명령이 0 으로 끝나야 통과
#   expect_eq "설명" <기대> <실제>  문자열이 같아야 통과
#   expect_grep "설명" <정규식> <파일>  /  expect_nogrep "설명" <정규식> <파일>
#   finish                          「단언: 통과 n · 실패 m」 을 적고, 실패가 있으면 exit 1
# 한 줄씩 ✓/✖ 로 적어 결과 본문(RESULT)에 그대로 남긴다.
ASSERT_PASS=0; ASSERT_FAIL=0; ASSERT_FAILS=()
_assert_ok() { ASSERT_PASS=$((ASSERT_PASS + 1)); echo "✓ $1"; }
_assert_ng() { ASSERT_FAIL=$((ASSERT_FAIL + 1)); ASSERT_FAILS+=("$1"); echo "✖ $1${2:+ — $2}"; }
expect() { local d=$1; shift; if "$@" > /dev/null 2>&1; then _assert_ok "$d"; else _assert_ng "$d"; fi; }
expect_eq() { if [ "$2" = "$3" ]; then _assert_ok "$1"; else _assert_ng "$1" "기대 [$2] · 실제 [$3]"; fi; }
expect_grep() { if grep -qE -- "$2" "$3" 2>/dev/null; then _assert_ok "$1"; else _assert_ng "$1" "「$2」 없음"; fi; }
expect_nogrep() { if grep -qE -- "$2" "$3" 2>/dev/null; then _assert_ng "$1" "「$2」 있음"; else _assert_ok "$1"; fi; }
finish() {
  echo
  echo "단언: 통과 $ASSERT_PASS · 실패 $ASSERT_FAIL"
  local x; for x in "${ASSERT_FAILS[@]}"; do echo "  ✖ $x"; done
  [ "$ASSERT_FAIL" -eq 0 ] && [ "$ASSERT_PASS" -gt 0 ] && exit 0
  exit 1
}
# procs_under <폴더> — 환경변수 SC_WORK·CODE1_STATE·HOME 이 그 폴더 아래인 살아 있는 프로세스 pid(시험이 남긴 감시기 등, D-0006). /proc 없으면 아무것도 안 냄.
procs_under() {
  local d=$1 p
  [ -d /proc/self ] || return 0
  for p in /proc/[0-9]*; do
    p=${p#/proc/}; [ "$p" = "$$" ] && continue
    { tr '\0' '\n' < "/proc/$p/environ"; } 2>/dev/null | grep -qE "^(SC_WORK|CODE1_STATE|HOME)=$d(/|\$)" && echo "$p"
  done
  return 0
}
