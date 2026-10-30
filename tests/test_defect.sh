#!/usr/bin/env bash
# 결함 티켓(type defect + tc) 시험(ORDER-26 2): tk new 거절·생성, validate 가 tc 실행, resolve → review, close(tc 재실행) → done, reopen.
# 사용: bash tests/test_defect.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/lib.sh" "$@"
tc_head "결함 티켓 = 티켓 + 재현 TC"
mkdir -p "$W/c"; bash "$T/install.sh" "$W/c" > /dev/null 2>&1
cd "$W/c"
mkdir -p tests/defects docs
printf '#!/usr/bin/env bash\n# 결함 재현 — FIXED 파일이 없으면 실패\n[ -e "$(dirname "$0")/../../FIXED" ]\n' > tests/defects/D-9001.sh
run() { "$@" > "$W/o.txt" 2>&1; echo $?; }
expect_eq "tk new defect — tc 없으면 거절(비영)" 1 "$(run python3 build/tk new --type defect --title 결함 --goal 재현 --outputs docs/D-9001.md)"
expect_grep "거절 사유 — --tc 필수" '\-\-tc .*필수' "$W/o.txt"
expect_eq "tk new defect — tc 파일이 없고 outputs 에도 없으면 거절" 1 "$(run python3 build/tk new --type defect --title 결함 --goal 재현 --outputs docs/D-9001.md --tc tests/defects/없음.sh)"
expect_eq "남은 티켓 0장(거절된 것은 안 만들어짐)" 0 "$(ls tickets/open/T-*.yaml 2>/dev/null | wc -l)"
expect_eq "tk new defect — tc 있으면 생성" 0 "$(run python3 build/tk new --type defect --title 결함 --goal 재현 --outputs docs/D-9001.md --tc tests/defects/D-9001.sh)"
TID=$(cut -d' ' -f1 "$W/o.txt"); F=tickets/open/$TID.yaml
expect_grep "티켓에 tc 기록" '^tc: tests/defects/D-9001.sh' "$F"
expect_grep "dod 에 tc 자동 추가" '^- tc' "$F"
expect_eq "tc 를 outputs 에 넣으면 아직 없어도 생성" 0 "$(run python3 build/tk new --type defect --title 결함2 --goal x --outputs tests/defects/D-9002.sh,docs/D-9002.md --tc tests/defects/D-9002.sh)"
printf -- '---\nid: D-9001\ntitle: 결함 산출물\nstatus: draft\n---\n\n## 본문\n결함 재현 TC 를 달고 고친 기록이다. 시험용 본문 사십 자를 넘기기 위한 문장[판단].\n' > docs/D-9001.md
python3 build/tk claim "$TID" s1 > /dev/null
expect_eq "validate --ticket — tc 실패(결함 남음)면 비영" 1 "$(run python3 build/validate --ticket "$TID")"
expect_grep "validate — 「tc 실패」 오류" '^오류 .*tc 실패\(exit 1\)' "$W/o.txt"
touch FIXED
expect_eq "validate --ticket — 고친 뒤 tc 통과면 0" 0 "$(run python3 build/validate --ticket "$TID")"
expect_grep "validate — 「tc 통과」" '^tc 통과: tests/defects/D-9001.sh' "$W/o.txt"
expect_eq "tk resolve — 커밋 없이는 거절" 1 "$(run python3 build/tk resolve "$TID")"
expect_eq "tk resolve — review 로" 0 "$(run python3 build/tk resolve "$TID" abc1234)"
expect "resolve 뒤 review 상태 · fixed_in" grep -q '^fixed_in: abc1234' "tickets/review/$TID.yaml"
expect_eq "tk resolve 두 번(멱등)" 0 "$(run python3 build/tk resolve "$TID" abc1234)"
rm FIXED
expect_eq "tk close — tc 가 다시 실패하면 거절" 1 "$(run python3 build/tk close "$TID" rv1)"
expect_grep "close 거절 사유" 'close 거절 — tc 실패' "$W/o.txt"
expect "close 거절 뒤에도 review 그대로" test -f "tickets/review/$TID.yaml"
touch FIXED
expect_eq "tk close — tc 통과면 done" 0 "$(run python3 build/tk close "$TID" rv1)"
expect "close 뒤 done · reviewed_by" grep -q '^reviewed_by: rv1' "tickets/done/$TID.yaml"
expect_eq "tk close 두 번(같은 리뷰어, 멱등)" 0 "$(run python3 build/tk close "$TID" rv1)"
expect_eq "tk reopen — open 으로" 0 "$(run python3 build/tk reopen "$TID" 다시 재현됨)"
expect "reopen 뒤 open · reviewed_by 비움" grep -q "^reviewed_by: ''" "tickets/open/$TID.yaml"
expect_eq "defect 가 아닌 티켓에 resolve — 거절" 1 "$(run python3 build/tk resolve "$(python3 build/tk new --type task --title t --goal g --outputs docs/x.md | cut -d' ' -f1)" abc)"
# 등록 주체 = 발견한 검수자, assignee = 오케스트레이터 역할(ORDER-38) — 결함인데 assignee 가 비면 validate 권고(done 제외)
run python3 build/validate --all > /dev/null
expect_grep "assignee 없는 open defect — 권고" "^권고 tickets/open/$TID.yaml: 결함 티켓에 assignee 없음" "$W/o.txt"
expect_eq "tk new --assignee — 생성" 0 "$(run python3 build/tk new --type defect --title 결함3 --goal 재현 --outputs docs/D-9003.md --tc tests/defects/D-9001.sh --assignee orchestrator)"
AID=$(cut -d' ' -f1 "$W/o.txt")
expect_grep "티켓에 assignee 기록" '^assignee: orchestrator' "tickets/open/$AID.yaml"
expect_eq "tk new process + dod tc(assignee 없음) — 생성" 0 "$(run python3 build/tk new --type process --title '[결함] 엔진 보호 경로' --goal 재현 --outputs build/x.py --dod tc --tc tests/defects/D-9001.sh)"
PID=$(cut -d' ' -f1 "$W/o.txt")
run python3 build/validate --all > /dev/null
expect_nogrep "assignee 있는 defect — 권고 없음" "^권고 tickets/open/$AID.yaml: .*assignee" "$W/o.txt"
expect_grep "dod tc 인 process 도 결함 — assignee 없으면 권고" "^권고 tickets/open/$PID.yaml: 결함 티켓에 assignee 없음" "$W/o.txt"
python3 build/tk set "$TID" assignee orchestrator > /dev/null
run python3 build/validate --all > /dev/null
expect_nogrep "tk set assignee 뒤 — 권고 사라짐" "^권고 tickets/open/$TID.yaml: .*assignee" "$W/o.txt"
python3 build/tk set "$TID" assignee "" > /dev/null; touch FIXED; python3 build/tk resolve "$TID" abc1234 > /dev/null; python3 build/tk close "$TID" rv1 > /dev/null
run python3 build/validate --all > /dev/null
expect_nogrep "done(closed) defect 는 assignee 권고 안 함" "^권고 tickets/done/$TID.yaml: .*assignee" "$W/o.txt"
python3 build/tk reopen "$TID" 시험 > /dev/null; rm -f FIXED
# 티켓 파일을 손으로 고쳐 tc 를 지운 defect 는 validate --all 이 잡는다
python3 - "$TID" << 'PY'
import sys, yaml; p = f"tickets/open/{sys.argv[1]}.yaml"; t = yaml.safe_load(open(p)); t.pop("tc"); yaml.safe_dump(t, open(p, "w"), allow_unicode=True, sort_keys=False)
PY
expect_eq "validate --all — tc 없는 defect 는 오류" 1 "$(run python3 build/validate --all)"
expect_grep "「defect 티켓에 tc 없음」" 'defect 티켓에 tc 없음' "$W/o.txt"
finish
