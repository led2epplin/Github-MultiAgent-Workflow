#!/usr/bin/env bash
# D-0004 defect 티켓이 close 검사(tc 재실행·reviewed_by) 없이 done 으로 간다 — tk done·tk move done 이 type defect 를 막지 않고,
#   validate --all 은 done 결함의 fixed_in·reviewed_by 를 보지 않는다(Cloud_codex1 ORDER-30 교차 검수 P0).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0004.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0004 defect 는 tk close 로만 done · done 결함은 fixed_in·reviewed_by 필수"
mkdir -p "$W/c"; bash "$T/install.sh" "$W/c" > /dev/null 2>&1; cd "$W/c"
mkdir -p tests/defects docs
printf '#!/usr/bin/env bash\nexit 23\n' > tests/defects/D-9100.sh           # 결함이 남아 있는 TC(늘 실패)
run() { "$@" > "$W/o.txt" 2>&1; echo $?; }
TID=$(python3 build/tk new --type defect --title 결함 --goal 재현 --outputs docs/D-9100.md --tc tests/defects/D-9100.sh | cut -d' ' -f1)
expect "defect 티켓 생성" test -f "tickets/open/$TID.yaml"
expect_eq "tk done — defect 는 거절(비영)" 1 "$([ "$(run python3 build/tk done "$TID")" -ne 0 ] && echo 1 || echo 0)"
expect_grep "tk done 거절 안내에 tk close" 'tk close' "$W/o.txt"
expect "tk done 뒤에도 done 아님" test ! -e "tickets/done/$TID.yaml"
expect_eq "tk move done — defect 는 거절(비영)" 1 "$([ "$(run python3 build/tk move "$TID" done)" -ne 0 ] && echo 1 || echo 0)"
expect "tk move done 뒤에도 done 아님" test ! -e "tickets/done/$TID.yaml"
expect_eq "tk move review — defect 도 다른 상태 이동은 됨" 0 "$(run python3 build/tk move "$TID" review)"
# 손으로 done 에 옮긴(검사를 건너뛴) defect — reviewed_by·fixed_in 이 비어 있다
mkdir -p tickets/done; git mv -k "tickets/review/$TID.yaml" "tickets/done/$TID.yaml" 2>/dev/null || mv "tickets/review/$TID.yaml" "tickets/done/$TID.yaml"
expect_eq "validate --all — reviewed_by 빈 done defect 는 오류(비영)" 1 "$([ "$(run python3 build/validate --all)" -ne 0 ] && echo 1 || echo 0)"
expect_grep "validate — done defect 의 reviewed_by 오류" "$TID.*reviewed_by" "$W/o.txt"
expect_grep "validate — done defect 의 fixed_in 오류" "$TID.*fixed_in" "$W/o.txt"
# 대조: tk close 경로(resolve → close)로 간 defect 는 validate 통과 — tc 를 고친 뒤
printf '#!/usr/bin/env bash\nexit 0\n' > tests/defects/D-9101.sh
T2=$(python3 build/tk new --type defect --title 결함2 --goal 재현 --outputs docs/D-9101.md --tc tests/defects/D-9101.sh | cut -d' ' -f1)
python3 build/tk resolve "$T2" abc1234 > /dev/null; python3 build/tk close "$T2" rv1 > /dev/null
expect "tk close 경로 — done" test -f "tickets/done/$T2.yaml"
run python3 build/validate --all > /dev/null
expect_nogrep "tk close 경로 defect 는 validate 오류 없음" "$T2" "$W/o.txt"
finish
