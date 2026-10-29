#!/usr/bin/env bash
# 다중 세션 claim — 임대·생존신고·인계·멱등(ORDER-26A 3). 동시 claim 경합은 tests/defects/D-0001.sh.
# 사용: bash tests/test_claim.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/lib.sh" "$@"
tc_head "claim 임대 · 생존신고 · 만료 인계 · 멱등"
mkdir -p "$W/c"; bash "$T/install.sh" "$W/c" > /dev/null 2>&1; cd "$W/c"
run() { "$@" > "$W/o.txt" 2>&1; echo $?; }
TID=$(python3 build/tk new --type task --title 임대 --goal x --outputs docs/x.md | cut -d' ' -f1)
lu() { python3 -c "import yaml,sys;print(yaml.safe_load(open('tickets/doing/$TID.yaml'))['claim'].get('$1',''))"; }
expect_eq "s1 claim" 0 "$(run python3 build/tk claim "$TID" s1)"
expect "claim 에 lease_until" test -n "$(lu lease_until)"
expect_eq "s1 이 다시 claim — 멱등(성공, 임대 연장)" 0 "$(run python3 build/tk claim "$TID" s1)"
expect_grep "멱등 claim 안내" '이미 claim' "$W/o.txt"
expect_eq "s2 claim — 임대 중이면 거절" 1 "$(run python3 build/tk claim "$TID" s2)"
expect_eq "s2 renew — 남의 티켓은 거절" 1 "$(run python3 build/tk renew "$TID" s2)"
expect_eq "s1 renew — 생존신고" 0 "$(run python3 build/tk renew "$TID" s1)"
python3 build/tk set "$TID" claim.lease_until "2000-01-01 00:00" > /dev/null
expect_eq "임대 만료 → s2 claim 이 인계" 0 "$(run python3 build/tk claim "$TID" s2)"
expect_grep "인계 안내" '인계 — 이전 s1' "$W/o.txt"
expect_eq "claim.by = s2" s2 "$(lu by)"
expect_grep "claim.prev 에 이전 세션" '^  prev: s1 ' "tickets/doing/$TID.yaml"
python3 build/tk set "$TID" claim.lease_until "" > /dev/null; python3 build/tk set "$TID" claim.at "2000-01-01 00:00" > /dev/null
expect_eq "lease_until 없는 옛 claim — claim.at + 임대로 만료 판정 → 인계" 0 "$(run python3 build/tk claim "$TID" s3)"
TID2=$(python3 build/tk new --type task --title 지정 --goal x --outputs docs/y.md | cut -d' ' -f1)
python3 build/tk set "$TID2" runner local- > /dev/null
expect_eq "runner 지정 티켓 — 다른 실행 세션의 ready 에서 빠짐" "" "$(HARNESS_RUNNER=gha-1 python3 build/ready --one 2>/dev/null)"
expect_eq "runner 지정 티켓 — 그 이름으로 시작하는 세션은 집음" "$TID2" "$(HARNESS_RUNNER=local-box python3 build/ready --one)"
finish
