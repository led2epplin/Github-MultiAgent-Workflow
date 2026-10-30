#!/usr/bin/env bash
# D-0010 validate --all 이 review·done 티켓의 「inputs 합계 > read_kb」 를 오류로 센다 — read_kb 는 작업자가 실행할 때 읽는 한도인데,
#   이미 끝난 티켓의 입력 파일이 나중에 커져도 저장소 전체 검증이 실패한다(소비 저장소에서 동기화 전부터 done 티켓 오류 15건, ORDER-34).
# 결함이 있으면 비영 종료. 사용: bash tests/defects/D-0010.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/../lib.sh" "$@"
tc_head "D-0010 read_kb 초과는 실행 대상(open·doing)만 오류 — hold·stranded 는 권고, review·done 은 검사 안 함"
show() { echo '```'; sed "s#$W#<임시폴더>#g; s/^/  /" "$1"; echo '```'; }
mkdir -p "$W/c"; bash "$T/install.sh" "$W/c" > /dev/null 2>&1; cd "$W/c"
mkdir -p inputs; head -c $((70 * 1024)) /dev/zero | tr "\0" x > inputs/big.txt          # 70KB > read_kb 기본 60KB
mk() {  # mk <상태> — 그 상태에 inputs 가 70KB 인 티켓 한 장, ID 를 돌려준다
  local id; id=$(python3 build/tk new --type card --title "큰 입력 $1" --goal x --inputs inputs/big.txt --outputs "docs/out-$1.md" | cut -d' ' -f1)
  [ "$1" = open ] || mv "tickets/open/$id.yaml" "tickets/$1/$id.yaml"
  echo "$id"
}
declare -A ID
for st in review done; do mkdir -p "tickets/$st"; ID[$st]=$(mk "$st"); done
python3 build/validate --all > "$W/v1.out" 2>&1; rc=$?; echo "review·done 만 초과:"; show "$W/v1.out"
expect_eq "review·done 초과만 — validate --all exit 0" 0 "$rc"
for st in review done; do
  expect_nogrep "$st 티켓 — read_kb 오류 없음" "^오류 tickets/$st/${ID[$st]}\.yaml: inputs 합계" "$W/v1.out"
done
for st in open doing hold stranded; do mkdir -p "tickets/$st"; ID[$st]=$(mk "$st"); done
python3 build/validate --all > "$W/v2.out" 2>&1; rc=$?; echo "모든 상태에 초과:"; show "$W/v2.out"
expect_eq "open·doing 초과 — validate --all exit 1" 1 "$rc"
for st in open doing; do
  expect_grep "$st 티켓 — read_kb 오류" "^오류 tickets/$st/${ID[$st]}\.yaml: inputs 합계 70KB > read_kb 60KB" "$W/v2.out"
done
for st in hold stranded; do
  expect_grep "$st 티켓 — read_kb 권고(오류 아님)" "^권고 tickets/$st/${ID[$st]}\.yaml: inputs 합계 70KB > read_kb 60KB" "$W/v2.out"
  expect_nogrep "$st 티켓 — read_kb 오류 없음" "^오류 tickets/$st/${ID[$st]}\.yaml: inputs 합계" "$W/v2.out"
done
for st in review done; do
  expect_nogrep "$st 티켓 — 여전히 read_kb 오류·권고 없음" "tickets/$st/${ID[$st]}\.yaml: inputs 합계" "$W/v2.out"
done
expect_grep "엔진 요약 — 오류 2 · 권고 2" '^validate\(engine\): 오류 2 / 권고 2' "$W/v2.out"
python3 build/validate --file "tickets/done/${ID[done]}.yaml" > "$W/v3.out" 2>&1; rc=$?
expect_eq "validate --file done 티켓 — exit 0" 0 "$rc"
finish
