#!/usr/bin/env bash
# D-0003 임대 인계 뒤 이전 작업자가 결과를 확정 — run_ticket.sh 가 실행기 뒤 validate·브랜치 push·상태 전이 사이에 claim 을 다시 보지 않아,
#   임대가 만료돼 B 가 인계 claim 한 티켓을 A 가 review 로 옮긴다. 실행기가 도는 동안 임대 연장도 없다(Cloud_codex1 ORDER-30 교차 검수 P0).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0003.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0003 임대 인계 뒤 이전 세션은 결과를 확정하지 않음 · 실행 중 임대 연장, 인계되면 실행기 종료"
engine_remote "$W/eng"
mkdir -p "$W/stub"
printf '%s\n' '#!/bin/sh' 'case "$1 $2" in "pr create") echo "https://example.invalid/pr/1";; esac' > "$W/stub/gh"   # PR 경로(가짜)
chmod 755 "$W/stub/gh"
setup_case() {  # setup_case <폴더> — 엔진 + 확정 역할표 + 기다리는 실행기 + 티켓 1장, 원격 bare
  local C=$1
  consumer "$C"; bash "$W/eng/install.sh" "$C" > /dev/null 2>&1
  manifest "$C" "$W/eng" "v$(cat "$W/eng/ENGINE_VERSION")" full "$ROLES_OK"
  # 시험용 실행기: 산출물을 쓰고 GO 파일이 생길 때까지(최대 25초) 기다린 뒤 끝 — 그동안 다른 세션이 인계한다
  printf '%s\n' '#!/usr/bin/env bash' 'T=$1; python3 domain/smoke.py "$T"; echo "실행기 시작 $T"' \
    'for i in $(seq 125); do [ -e "$GO" ] && break; sleep 0.2; done; echo "실행기 끝 $T"' > "$C/.mawf/runner.sh"
  TID=$(cd "$C" && python3 build/tk new --type smoke --title 인계 --goal x --outputs docs/L-1.md | cut -d' ' -f1)
  ( cd "$C" && git add -A && git commit -qm "엔진 + 역할표 + 실행기 + 티켓" && git push -q origin main )
  git clone -q "$C.remote.git" "$C-a"; git clone -q "$C.remote.git" "$C-b"
}
wait_claim() { local i; for i in $(seq 100); do git --git-dir="$1.remote.git" log --format=%s main | grep -q "^claim $TID (A)" && return 0; sleep 0.2; done; return 1; }
take_over() {   # take_over <폴더> <방식> — B 가 인계: expire = 임대를 과거로 돌린 뒤 tk claim / direct = claim 을 B 로 한 번에(연장과 경합해도 되게)
  local C=$1 i
  for i in 1 2 3 4 5; do
    ( cd "$C-b" && git fetch -q origin main && git reset -q --hard origin/main
      if [ "$2" = expire ]; then python3 build/tk set "$TID" claim.lease_until "2000-01-01 00:00" > /dev/null && python3 build/tk claim "$TID" B > /dev/null
      else python3 build/tk set "$TID" claim.by B > /dev/null && python3 build/tk set "$TID" claim.at "2099-01-01 00:00" > /dev/null; fi
      git add -A && git commit -qm "takeover $TID (B)" && git push -q origin main ) 2>/dev/null && return 0
    sleep 0.5
  done; return 1
}
remote_state() { local C=$1 p; p=$(git --git-dir="$C.remote.git" ls-tree -r --name-only main tickets/ | grep "$TID"); echo "$p $(git --git-dir="$C.remote.git" show "main:$p" | python3 -c 'import sys,yaml;print((yaml.safe_load(sys.stdin) or {}).get("claim",{}).get("by"))')"; }
check() {       # check <폴더> <이름>
  local C=$1 tag=$2
  echo '```'; sed 's/^/  /' "$W/$tag.log" | head -14; echo "[원격 main]"; git --git-dir="$C.remote.git" log --format='  %s' main | head -6
  echo "[원격 브랜치]"; git --git-dir="$C.remote.git" for-each-ref --format='  %(refname:short)' refs/heads; echo '```'
  expect_eq "$tag — 원격 티켓은 doing · claim = B" "tickets/doing/$TID.yaml B" "$(remote_state "$C")"
  expect_eq "$tag — A 의 review 전이 없음" 0 "$(git --git-dir="$C.remote.git" log --format=%s main | grep -c "^review $TID")"
  expect "$tag — A 의 t/$TID 브랜치 push 없음" test -z "$(git --git-dir="$C.remote.git" for-each-ref "refs/heads/t/$TID")"
  expect_grep "$tag — A 로그에 「인계 … 확정 중지/실행기 종료」" '인계' "$W/$tag.log"
}

echo "## 1. 실행기가 기다리는 사이 임대 만료 → B 가 tk claim(인계) → A 재개"
C="$W/c1"; setup_case "$C"; export GO="$W/go1"
( cd "$C-a" && PATH="$W/stub:$PATH" HARNESS_RUNNER=A MAWF_RENEW_SEC=3600 BUDGET_MIN=5 MAX_TICKETS=1 bash build/run_ticket.sh > "$W/s1.log" 2>&1 ) &
AP=$!
wait_claim "$C" && take_over "$C" expire; touch "$GO"; wait "$AP"
check "$C" s1

echo; echo "## 2. 실행기가 도는 동안 임대 연장(2초마다) — B 가 인계하면 연장이 거절돼 실행기를 끝냄(GO 없이)"
C="$W/c2"; setup_case "$C"; export GO="$W/go2-never"
t0=$(date +%s)
( cd "$C-a" && PATH="$W/stub:$PATH" HARNESS_RUNNER=A MAWF_RENEW_SEC=2 BUDGET_MIN=5 MAX_TICKETS=1 bash build/run_ticket.sh > "$W/s2.log" 2>&1 ) &
AP=$!
# 시간이 흐른 것처럼 A 의 임대를 짧게(by·at 은 그대로) → A 의 연장이 원격에 「renew」 로 올라오는지 → 그 뒤 B 가 인계
wait_claim "$C" && ( cd "$C-b" && git pull -q && python3 build/tk set "$TID" claim.lease_until "2000-01-01 00:00" > /dev/null && git commit -qam "임대 짧게(시험)" && git push -q origin main )
for i in $(seq 50); do git --git-dir="$C.remote.git" log --format=%s main | grep -q "^renew $TID (A)" && break; sleep 0.2; done
take_over "$C" direct; wait "$AP"; dt=$(( $(date +%s) - t0 ))
check "$C" s2
expect_eq "s2 — 실행 중 임대 연장 커밋(renew … (A))" 1 "$([ "$(git --git-dir="$C.remote.git" log --format=%s main | grep -c "^renew $TID (A)")" -ge 1 ] && echo 1 || echo 0)"
expect_nogrep "s2 — 실행기가 GO 전에 끝남(「실행기 끝」 없음)" '실행기 끝' "$C-a/runs/$TID.log"
expect "s2 — 실행기 대기(25초)보다 빨리 끝남(${dt}초)" test "$dt" -lt 22
finish
