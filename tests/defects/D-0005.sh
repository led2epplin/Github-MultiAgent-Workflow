#!/usr/bin/env bash
# D-0005 두 세션이 같은 작업 브랜치 t/<T> 를 -f 로 덮음 — 작업 브랜치 이름이 티켓 ID 하나라, 같은 티켓을 차례로(인계·재작업) 처리한
#   A·B 가 같은 t/<T> 를 force push 한다 → 먼저 처리한 쪽 작업물이 원격에서 사라지고, A 의 PR 이 B 의 커밋을 가리킨다(최종 리뷰어 지적, ORDER-32 보충 2).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0005.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0005 작업 브랜치는 세션·claim 세대마다 따로 — 남의 브랜치를 -f 로 덮지 않음"
engine_remote "$W/eng"; C="$W/c"
consumer "$C"; bash "$W/eng/install.sh" "$C" > /dev/null 2>&1
manifest "$C" "$W/eng" "v$(cat "$W/eng/ENGINE_VERSION")" full "$ROLES_OK"
printf '%s\n' '#!/usr/bin/env bash' 'python3 domain/smoke.py "$1"' > "$C/.mawf/runner.sh"      # 시험용 실행기: 바로 산출물
mkdir -p "$W/stub"   # 가짜 gh — pr create 의 --head 를 적고 그 이름이 든 주소를 돌려준다
printf '%s\n' '#!/bin/sh' 'if [ "$1 $2" = "pr create" ]; then h=; p=; for a; do [ "$p" = --head ] && h=$a; p=$a; done' \
  "  echo \"\$h\" >> \"$W/gh_heads.log\"; echo \"https://example.invalid/pr/\$h\"; fi" > "$W/stub/gh"; chmod 755 "$W/stub/gh"
TID=$(cd "$C" && python3 build/tk new --type smoke --title 브랜치 --goal x --outputs docs/B-1.md | cut -d' ' -f1)
( cd "$C" && git add -A && git commit -qm "엔진 + 역할표 + 실행기 + 티켓" && git push -q origin main )
git clone -q "$C.remote.git" "$C-a"; git clone -q "$C.remote.git" "$C-b"
run_h() { ( cd "$C-$1" && git pull -q origin main && PATH="$W/stub:$PATH" HARNESS_RUNNER=$2 MAWF_RENEW_SEC=3600 BUDGET_MIN=5 MAX_TICKETS=1 bash build/run_ticket.sh ) > "$W/$2.log" 2>&1; }
run_h a A                                                     # A 가 처리 → PR → review
( cd "$C-b" && git pull -q origin main && python3 build/tk move "$TID" open > /dev/null && python3 build/tk set "$TID" claim.by "" > /dev/null \
  && git commit -qam "되돌림 — 재작업/인계(시험)" && git push -q origin main )      # 검수자가 되돌리거나 인계 — 다시 open
sleep 61                                                      # 다른 claim 세대(claim.at 분 단위)가 되게
run_h b B                                                     # B 가 같은 티켓을 처리 → PR
echo '```'; echo "[A]"; sed 's/^/  /' "$W/A.log" | head -8; echo "[B]"; sed 's/^/  /' "$W/B.log" | head -8
echo "[원격 작업 브랜치]"; git --git-dir="$C.remote.git" for-each-ref --format='  %(refname:short) ← %(subject)' "refs/heads/t/"; echo "[PR --head]"; sed 's/^/  /' "$W/gh_heads.log"; echo '```'
brs=$(git --git-dir="$C.remote.git" for-each-ref --format='%(refname:short)' "refs/heads/t/" | grep -c "^t/$TID")
expect_eq "원격에 이 티켓의 작업 브랜치 2개(A·B 따로)" 2 "$brs"
expect_eq "A 의 작업물 커밋이 원격 작업 브랜치 끝에 남음" 1 "$(git --git-dir="$C.remote.git" for-each-ref --format='%(subject)' "refs/heads/t/" | grep -c "^work $TID (A)")"
HB=$(sed -n 2p "$W/gh_heads.log")
expect "B 의 PR head 브랜치가 원격에 있음($HB)" git --git-dir="$C.remote.git" rev-parse -q --verify "refs/heads/$HB"
expect_eq "B 의 PR head 끝 커밋 = B 의 작업" "work $TID (B)" "$(git --git-dir="$C.remote.git" log -1 --format=%s "refs/heads/$HB" 2>/dev/null)"
expect "A·B 의 PR head 가 다름" test "$(sed -n 1p "$W/gh_heads.log")" != "$HB"
finish
