#!/usr/bin/env bash
# D-0001 claim 경합에서 진 세션이 rebase 중간 상태로 남음 — push_main 의 「rebase 후 재시도」 가 claim 에도 쓰여,
#   같은 티켓을 동시에 집은 두 번째 세션의 rebase 가 충돌로 멈추고 거둬지지 않는다(다음 push 가 전부 실패).
#   같은 역할 세션 2개가 같은 티켓을 동시에 집으면 하나만 성공해야 한다(WORKFLOW.md §4).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0001.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0001 같은 티켓 동시 claim — 하나만 성공, 진 쪽은 깨끗이 물러남"
engine_remote "$W/eng"
consumer "$W/c"
bash "$W/eng/install.sh" "$W/c" > "$W/install.out" 2>&1 || { cat "$W/install.out"; }
manifest "$W/c" "$W/eng" "v$(cat "$W/eng/ENGINE_VERSION")" full "$ROLES_OK"   # 1.1.0 부터는 역할표가 있어야 하니스가 claim 한다(이전 판은 무시)
( cd "$W/c" && python3 build/tk new --type smoke --title "경합 시험" --goal "같은 티켓 동시 claim" --outputs docs/SMOKE-1.md > /dev/null \
  && git add -A && git commit -qm "engine + 티켓" && git push -q origin main )
TID=$(cd "$W/c" && python3 build/ready --one)
git clone -q "$W/c.remote.git" "$W/a"; git clone -q "$W/c.remote.git" "$W/b"
# 경합을 결정적으로: A 의 push 는 B 가 claim 커밋을 만들 때까지 기다리고, B 의 push 는 A 의 claim 이 원격에 올라간 뒤 나간다
cat > "$W/a/.git/hooks/pre-push" << HOOK
#!/bin/sh
for i in \$(seq 150); do [ -e "$W/b_claimed" ] && exit 0; sleep 0.2; done; exit 0
HOOK
cat > "$W/b/.git/hooks/pre-push" << HOOK
#!/bin/sh
touch "$W/b_claimed"
for i in \$(seq 150); do git --git-dir="$W/c.remote.git" log --format=%s main | grep -q "^claim $TID (A)" && exit 0; sleep 0.2; done; exit 0
HOOK
chmod 755 "$W/a/.git/hooks/pre-push" "$W/b/.git/hooks/pre-push"
( cd "$W/a" && HARNESS_RUNNER=A DRY_RUN=1 NO_PR=1 BUDGET_MIN=5 MAX_TICKETS=1 bash build/run_ticket.sh > "$W/a.log" 2>&1; echo $? > "$W/a.rc" ) &
( cd "$W/b" && HARNESS_RUNNER=B DRY_RUN=1 NO_PR=1 BUDGET_MIN=5 MAX_TICKETS=1 bash build/run_ticket.sh > "$W/b.log" 2>&1; echo $? > "$W/b.rc" ) &
wait
echo '```'; echo "[A]"; sed 's/^/  /' "$W/a.log"; echo "[B]"; sed 's/^/  /' "$W/b.log"
echo "[원격 main]"; git --git-dir="$W/c.remote.git" log --format='  %s' main | head -8; echo '```'
claims=$(git --git-dir="$W/c.remote.git" log --format=%s main | grep -c "^claim $TID ")
expect_eq "원격 main 의 claim 커밋 1개(하나만 성공)" 1 "$claims"
expect_grep "A 가 claim 해 review 까지" "티켓 $TID 집음" "$W/a.log"
expect_grep "B 는 claim push 거절로 물러남" "claim push 거절" "$W/b.log"
expect_eq "B 하니스 exit 0" 0 "$(cat "$W/b.rc")"
expect "B 저장소에 rebase 잔여 없음(.git/rebase-merge·rebase-apply)" test ! -e "$W/b/.git/rebase-merge" -a ! -e "$W/b/.git/rebase-apply"
expect "A 저장소에도 rebase 잔여 없음(마지막 status push 경합)" test ! -e "$W/a/.git/rebase-merge" -a ! -e "$W/a/.git/rebase-apply"
expect "B 저장소가 main 에 깨끗이(git status 빈칸)" test -z "$(git -C "$W/b" status --porcelain 2>&1)"
st=$(git --git-dir="$W/c.remote.git" ls-tree -r --name-only main tickets/ | grep "$TID")
expect_eq "티켓은 review 에, claim = A" "tickets/review/$TID.yaml A" "$st $(git --git-dir="$W/c.remote.git" show "main:$st" 2>/dev/null | python3 -c 'import sys,yaml;print((yaml.safe_load(sys.stdin) or {}).get("claim",{}).get("by"))')"
# 진 쪽이 다음 일을 할 수 있는가 — B 에서 아무 커밋이나 push(rebase 잔여가 있으면 실패)
( cd "$W/b" && git pull -q --rebase origin main && echo x > b-next.txt && git add b-next.txt && git commit -qm "B 다음 일" && git push -q origin main ) > "$W/b2.log" 2>&1
expect "B 가 경합 뒤 다음 push 를 할 수 있음" grep -q "^B 다음 일" <(git --git-dir="$W/c.remote.git" log --format=%s main)
finish
