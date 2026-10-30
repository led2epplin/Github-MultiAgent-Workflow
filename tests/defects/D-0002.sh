#!/usr/bin/env bash
# D-0002 역할표 철회가 실행 중 하니스에 반영 안 됨 — run_ticket.sh 의 역할표 검사가 루프 전 1회라, sync_main 이 받아 온
#   roles={}(철회)·open-channel 을 보지 않고 ready 티켓을 claim 한다(Cloud_codex1 ORDER-30 교차 검수 P0).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0002.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0002 역할표가 원격에서 철회되면 하니스는 claim 하지 않음"
engine_remote "$W/eng"
i=0
for roles in 'roles: {}' 'roles: {mode: open-channel}'; do
  i=$((i + 1)); C="$W/c$i"
  consumer "$C"; bash "$W/eng/install.sh" "$C" > /dev/null 2>&1
  manifest "$C" "$W/eng" "v$(cat "$W/eng/ENGINE_VERSION")" full "$ROLES_OK"
  TID=$(cd "$C" && python3 build/tk new --type smoke --title 철회 --goal x --outputs docs/R-1.md | cut -d' ' -f1)
  ( cd "$C" && git add -A && git commit -qm "엔진 + 확정 역할표 + 티켓" && git push -q origin main )
  git clone -q "$C.remote.git" "$C-a"; git clone -q "$C.remote.git" "$C-b"     # A 는 철회 전 판(확정 역할표)을 들고 있다
  ( cd "$C-b" && python3 - "$roles" << 'PY'
import re, sys
s = open(".mawf.yaml").read()
open(".mawf.yaml", "w").write(re.sub(r"(?ms)^roles:.*\Z", sys.argv[1] + "\n", s))   # 역할표를 통째로 바꾼다(철회)
PY
    git commit -qam "역할표 철회: $roles" && git push -q origin main )
  ( cd "$C-a" && HARNESS_RUNNER=A DRY_RUN=1 NO_PR=1 BUDGET_MIN=5 MAX_TICKETS=1 bash build/run_ticket.sh ) > "$W/a$i.log" 2>&1; rc=$?
  echo "B 가 「$roles」 push → A 하니스(철회 전 checkout 에서 시작): exit $rc"; echo '```'; sed 's/^/  /' "$W/a$i.log" | head -8; echo '```'
  expect_eq "「$roles」 — 원격 claim 커밋 0" 0 "$(git --git-dir="$C.remote.git" log --format=%s main | grep -c '^claim ' || true)"
  expect_eq "「$roles」 — A 하니스 exit 0" 0 "$rc"
  expect_grep "「$roles」 — 「claim 없음」 안내" 'claim 없음' "$W/a$i.log"
  expect "「$roles」 — 티켓 $TID 은 open 그대로" git --git-dir="$C.remote.git" cat-file -e "main:tickets/open/$TID.yaml"
done
finish
