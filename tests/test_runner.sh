#!/usr/bin/env bash
# 작업자 실행기 계약(WORKFLOW.md §8) — 하니스가 .mawf/runner.sh 를 부르고, 75 = 실행기 장애(반려 아님·open 복귀·exit 2), 0 = validate 로 판정.
# 사용: bash tests/test_runner.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/lib.sh" "$@"
tc_head "작업자 실행기 계약 — 프로젝트 실행기 · 장애 75 · 정상 → review"
engine_remote "$W/eng"; consumer "$W/c"
manifest "$W/c" "$W/eng" "v$(cat "$W/eng/ENGINE_VERSION")" full "$ROLES_OK"
(cd "$W/c" && python3 "$W/eng/engine/build/engine_sync" > "$W/sync.out" 2>&1)   # 엔진 checkout 의 원본을 소비 저장소 폴더에서 — 첫 동기화
expect "첫 동기화(엔진 checkout 원본을 소비 저장소에서 실행) — build/run_ticket.sh 생김" test -f "$W/c/build/run_ticket.sh"
cat > "$W/c/.mawf/runner.sh" << 'R'
#!/usr/bin/env bash
# 시험용 실행기 — MODE 파일이 fail 이면 장애(75), 아니면 smoke 산출물을 쓰고 0
T=$1; echo "args=$* TICKET=$TICKET MAX_TURNS=$MAX_TURNS RUNS_DIR=$RUNS_DIR" > "$RUNS_DIR/$T.json"
if [ "$(cat "$(dirname "$0")/MODE" 2>/dev/null)" = fail ]; then echo "인증 실패(시험)" > "$RUNS_DIR/$T.runner_error"; exit 75; fi
python3 domain/smoke.py "$T"
R
echo fail > "$W/c/.mawf/MODE"
(cd "$W/c" && python3 build/tk new --type smoke --title 실행기 --goal x --outputs docs/RUN-1.md > /dev/null && git add -A && git commit -qm "엔진 + 티켓" && git push -q origin main)
TID=$(cd "$W/c" && python3 build/ready --one)
(cd "$W/c" && HARNESS_RUNNER=r1 NO_PR=1 bash build/run_ticket.sh) > "$W/h1.out" 2>&1; rc=$?
echo '```'; sed 's/^/  /' "$W/h1.out"; echo '```'
expect_eq "실행기 장애(75) → 하니스 exit 2" 2 "$rc"
expect_grep "「실행기 장애: 인증 실패(시험)」" '실행기 장애: 인증 실패\(시험\)' "$W/h1.out"
st=$(git --git-dir="$W/c.remote.git" ls-tree -r --name-only main tickets/ | grep "$TID")
expect_eq "티켓 open 복귀" "tickets/open/$TID.yaml" "$st"
expect_eq "반려로 세지 않음(rejected 0)" 0 "$(git --git-dir="$W/c.remote.git" show "main:$st" | python3 -c 'import sys,yaml;print(yaml.safe_load(sys.stdin).get("rejected"))')"
expect_grep "notes 에 runner-fail · 실행 세션 이름" 'runner-fail .* r1\] 인증 실패' <(git --git-dir="$W/c.remote.git" show "main:$st")
echo ok > "$W/c/.mawf/MODE"; (cd "$W/c" && git add -A && git commit -qm mode && git push -q origin main)
(cd "$W/c" && HARNESS_RUNNER=r1 NO_PR=1 bash build/run_ticket.sh) > "$W/h2.out" 2>&1; rc=$?
echo '```'; sed 's/^/  /' "$W/h2.out"; echo '```'
expect_eq "정상 실행기 → 하니스 exit 0" 0 "$rc"
expect_eq "티켓 review" "tickets/review/$TID.yaml" "$(git --git-dir="$W/c.remote.git" ls-tree -r --name-only main tickets/ | grep "$TID")"
expect_grep "실행기가 받은 계약(인수·TICKET·MAX_TURNS·RUNS_DIR)" "args=$TID TICKET=$TID MAX_TURNS=40 RUNS_DIR=$W/c/runs" "$W/c/runs/$TID.json"
expect_grep "커밋에 실행 세션 이름" "^work $TID \(r1\)" <(git --git-dir="$W/c.remote.git" log --format=%s main)
finish
