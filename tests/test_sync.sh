#!/usr/bin/env bash
# 엔진 동기화·매니페스트·역할표 시험(ORDER-26 · 26B). 외부 접속 없음 — 엔진 「원격」 은 로컬 git 저장소.
# 사용: bash tests/test_sync.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/lib.sh" "$@"
tc_head "엔진 동기화(full·docs) · 같은 ref 무변경 · 못 닿을 때 · 역할표 · 어댑터"
engine_remote "$W/eng"; V=$(cat "$W/eng/ENGINE_VERSION"); SYNC="$W/eng/engine/build/engine_sync"
show() { echo '```'; sed 's/^/  /' "$1"; echo '```'; }

echo "## 1. 빈 저장소 — mode full"
consumer "$W/full"; manifest "$W/full" "$W/eng" "v$V" full
MAWF_ROOT="$W/full" python3 "$SYNC" > "$W/full1.out" 2>&1; rc=$?; show "$W/full1.out"
expect_eq "full 첫 동기화 exit 0" 0 "$rc"
expect_grep "full — 첫 줄 「역할 미정」(roles 비어 있음)" '^역할 미정 — 사용자와 역할표 확정 필요' <(head -1 "$W/full1.out")
expect_grep "full — 갱신 줄(없음 → $V)" "엔진 없음 → $V\(full\) 갱신" "$W/full1.out"
for f in build/tk build/engine_sync build/run_ticket.sh .claude/settings.json .claude/skills/work/SKILL.md .github/workflows/harness.yml .mawf/WORKFLOW.md tickets/open/.gitkeep; do
  expect "full — $f 있음" test -f "$W/full/$f"
done
expect_eq "full — ENGINE_VERSION = $V" "$V" "$(cat "$W/full/ENGINE_VERSION" 2>/dev/null)"
expect "full — .mawf/WORKFLOW.md = 엔진 판" cmp -s "$W/eng/engine/WORKFLOW.md" "$W/full/.mawf/WORKFLOW.md"
expect "full — 매니페스트는 그대로(프로젝트 소유)" grep -q "repo: $W/eng" "$W/full/.mawf.yaml"
(cd "$W/full" && git add -A && git commit -qm "engine $V")
(cd "$W/full" && python3 build/engine_sync) > "$W/full2.out" 2>&1; rc=$?; show "$W/full2.out"
expect_eq "full 같은 ref 재실행 exit 0" 0 "$rc"
expect_grep "full 재실행 — 「변경 없음」" '변경 없음' "$W/full2.out"
expect_eq "full 재실행 — 작업 트리 무변경" "" "$(git -C "$W/full" status --porcelain)"
rm "$W/full/.mawf/WORKFLOW.md"
(cd "$W/full" && python3 build/engine_sync) > "$W/full3.out" 2>&1
expect "full — 같은 ref 라도 파일이 빠졌으면 다시 받음" test -f "$W/full/.mawf/WORKFLOW.md"
expect_eq "full — 다시 받은 뒤 작업 트리 = 커밋본" "" "$(git -C "$W/full" status --porcelain)"

echo; echo "## 2. 빈 저장소 — mode docs"
consumer "$W/docs"; manifest "$W/docs" "$W/eng" "v$V" docs 'roles: {mode: open-channel}'
MAWF_ROOT="$W/docs" python3 "$SYNC" > "$W/docs1.out" 2>&1; rc=$?; show "$W/docs1.out"
expect_eq "docs 첫 동기화 exit 0" 0 "$rc"
expect_nogrep "docs — open-channel 이면 「역할 미정」 없음" '역할 미정' "$W/docs1.out"
expect "docs — .mawf/WORKFLOW.md = 엔진 판" cmp -s "$W/eng/engine/WORKFLOW.md" "$W/docs/.mawf/WORKFLOW.md"
expect "docs — .mawf/engine_sync 있음" test -x "$W/docs/.mawf/engine_sync"
expect_eq "docs — .mawf/ENGINE_VERSION = $V" "$V" "$(cat "$W/docs/.mawf/ENGINE_VERSION" 2>/dev/null)"
expect "docs — build/ 없음" test ! -e "$W/docs/build"
expect "docs — .claude/ 없음" test ! -e "$W/docs/.claude"
expect_eq "docs — 만든 파일은 .mawf/ 3개뿐" ".mawf/ENGINE_VERSION .mawf/WORKFLOW.md .mawf/engine_sync" "$(cd "$W/docs" && git add -A -n . | sed "s/^add '//;s/'$//" | grep -v '^\.mawf\.yaml$' | sort | tr '\n' ' ' | sed 's/ $//')"
(cd "$W/docs" && git add -A && git commit -qm "docs sync")
(cd "$W/docs" && python3 .mawf/engine_sync) > "$W/docs2.out" 2>&1; rc=$?; show "$W/docs2.out"
expect_eq "docs 같은 ref 재실행 exit 0" 0 "$rc"
expect_grep "docs 재실행 — 「변경 없음」" '변경 없음' "$W/docs2.out"
expect_eq "docs 재실행 — 작업 트리 무변경" "" "$(git -C "$W/docs" status --porcelain)"
(cd "$W/docs" && MAWF_NO_PYYAML=1 python3 .mawf/engine_sync) > "$W/docs3.out" 2>&1
expect_grep "docs — PyYAML 없이(내장 해석기)도 같은 판정" '변경 없음' "$W/docs3.out"

echo; echo "## 3. 엔진 저장소에 못 닿을 때 — 안내 1줄, 비영 아님"
for spec in "$W/없는/엔진" "nobody-owner/no-such-engine-repo"; do
  manifest "$W/docs" "$spec" v9.9.9 docs 'roles: {mode: open-channel}'
  (cd "$W/docs" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=url.http://127.0.0.1:9/.insteadOf GIT_CONFIG_VALUE_0=https://github.com/ MAWF_SYNC_TIMEOUT=10 python3 .mawf/engine_sync) > "$W/off.out" 2>&1; rc=$?; show "$W/off.out"
  expect_eq "못 닿음($spec) — exit 0" 0 "$rc"
  expect_eq "못 닿음($spec) — 출력 1줄" 1 "$(wc -l < "$W/off.out")"
  expect_grep "못 닿음($spec) — 「닿지 못함 … add_repo … 다시 실행」" '닿지 못함.*add_repo .*engine_sync 다시 실행' "$W/off.out"
done
(cd "$W/docs" && git checkout -q -- .mawf.yaml)
expect_eq "못 닿음 — .mawf/ 무변경" "" "$(git -C "$W/docs" status --porcelain)"
(cd "$W/docs" && python3 .mawf/engine_sync --check) > "$W/chk.out" 2>&1
expect_grep "--check — 같은 판이면 변경 없음" '변경 없음' "$W/chk.out"

echo; echo "## 4. 역할표 판정 — engine_sync --roles · session_start · install.sh · 하니스"
roles_rc() { manifest "$W/full" "$W/eng" "v$V" full "$1"; (cd "$W/full" && python3 build/engine_sync --roles > "$W/roles.out" 2>&1; echo $?); }
expect_eq "roles: {} → 3(미정)" 3 "$(roles_rc 'roles: {}')"
expect_grep "roles: {} → 「역할 미정」 한 줄" '^역할 미정 — 사용자와 역할표 확정 필요' "$W/roles.out"
expect_eq "roles 키 없음 → 3" 3 "$(roles_rc '')"
expect_eq "table 있고 confirmed 없음 → 3" 3 "$(roles_rc 'roles:
  table:
    worker: {count: 1}')"
expect_grep "confirmed 없음 사유" 'roles.confirmed' "$W/roles.out"
expect_eq "open-channel → 4, 안내 없음" "4 0" "$(roles_rc 'roles: {mode: open-channel}') $(wc -c < "$W/roles.out")"
expect_eq "확정 역할표 → 0, 안내 없음" "0 0" "$(roles_rc "$ROLES_OK") $(wc -c < "$W/roles.out")"
manifest "$W/full" "$W/eng" "v$V" full 'roles: {}'
(cd "$W/full" && python3 build/session_start) > "$W/ss.out" 2>&1
expect_grep "session_start(대화형) — 첫 줄 「역할 미정」" '^역할 미정 — 사용자와 역할표 확정 필요' <(head -1 "$W/ss.out")
expect_grep "session_start(대화형) — 엔진 줄(변경 없음)" '^\[엔진\] .*변경 없음' "$W/ss.out"
(cd "$W/full" && TICKET=T-none python3 build/session_start) > "$W/ssw.out" 2>&1
expect_grep "session_start(작업자) — 첫 줄 「역할 미정」" '^역할 미정' <(head -1 "$W/ssw.out")
mkdir -p "$W/inst"; bash "$W/eng/install.sh" "$W/inst" > "$W/inst.out" 2>&1; show "$W/inst.out"
expect_grep "install.sh(빈 폴더) — 첫 줄 「역할 미정」" '^역할 미정 — 사용자와 역할표 확정 필요' <(head -1 "$W/inst.out")
expect_grep "install.sh — 매니페스트를 엔진 판으로 만들어 둠(ref v$V)" "^  ref: v$V " "$W/inst/.mawf.yaml"
# 하니스: 역할 미정이면 ready 티켓이 있어도 claim 없음(exit 0)
(cd "$W/full" && git checkout -q -- .mawf.yaml && python3 build/tk new --type smoke --title 역할시험 --goal x --outputs docs/R-1.md > /dev/null && git add -A && git commit -qm t && git push -q origin main)
(cd "$W/full" && DRY_RUN=1 NO_PR=1 HARNESS_RUNNER=h1 bash build/run_ticket.sh) > "$W/h.out" 2>&1; rc=$?; show "$W/h.out"
expect_eq "하니스(역할 미정) exit 0" 0 "$rc"
expect_grep "하니스 — 「역할 미정 … claim 없음」" '역할 미정.*claim 없음' "$W/h.out"
expect_eq "하니스 — 티켓은 open 그대로 · claim 커밋 없음" "1 0" "$(ls "$W/full/tickets/open/"T-*.yaml | wc -l) $(git -C "$W/full" log --format=%s | grep -c '^claim ')"
manifest "$W/full" "$W/eng" "v$V" full 'roles: {mode: open-channel}'
(cd "$W/full" && DRY_RUN=1 NO_PR=1 HARNESS_RUNNER=h1 bash build/run_ticket.sh) > "$W/h2.out" 2>&1; rc=$?
expect_eq "하니스(open-channel) exit 0 · 「대화 창구」" "0 1" "$rc $(grep -c '대화 창구' "$W/h2.out")"
manifest "$W/full" "$W/eng" "v$V" full "$ROLES_OK"
(cd "$W/full" && HARNESS_RUNNER=h1 bash build/run_ticket.sh) > "$W/h3.out" 2>&1; rc=$?; show "$W/h3.out"
expect_eq "하니스(역할 확정·실행기 없음) — claim 전에 멈춤(exit 1)" 1 "$rc"
expect_eq "실행기 없음 — 티켓 open 그대로" 1 "$(ls "$W/full/tickets/open/"T-*.yaml | wc -l)"

echo; echo "## 5. 작업자 실행기 어댑터 · 설정 주입"
printf 'runner:\n  adapter: claude-code\n  git_name: proj-harness\n' >> "$W/full/.mawf.yaml"
(cd "$W/full" && python3 build/engine_sync) > "$W/ad.out" 2>&1; show "$W/ad.out"
expect "어댑터 — .mawf/runner/runner.sh 복사" test -x "$W/full/.mawf/runner/runner.sh"
expect_eq "어댑터 — ADAPTER 표시" claude-code "$(cat "$W/full/.mawf/runner/ADAPTER" 2>/dev/null)"
cfg=$(cd "$W/full" && python3 build/engine_sync --runner-cfg | tr '\n' ' ')
expect_eq "runner-cfg — 어댑터 기본 + 매니페스트 덮어쓰기" "token_secret=CLAUDE_CODE_OAUTH_TOKEN node=22 git_name=proj-harness git_email=mawf-harness@users.noreply.github.com " "$cfg"
printf '  token_secret: MY_TOKEN\n' >> "$W/full/.mawf.yaml"
expect_eq "runner-cfg — token_secret 매니페스트 우선" MY_TOKEN "$(cd "$W/full" && python3 build/engine_sync --runner-cfg token_secret)"
expect_eq "runner-cfg(어댑터 없음) — 기본 git_name" mawf-harness "$(cd "$W/docs" && python3 .mawf/engine_sync --runner-cfg git_name)"

echo; echo "## 6. 태그 없이 커밋 해시로 판 고정(ORDER-33) — engine.ref = 40자 sha, 로컬 bare 원격"
git clone -q --bare "$W/eng" "$W/eng-bare.git"; SHA=$(git --git-dir="$W/eng-bare.git" rev-parse HEAD)
for mode in docs full; do
  d="$W/sha-$mode"; consumer "$d"; manifest "$d" "$W/eng-bare.git" "$SHA" "$mode" 'roles: {mode: open-channel}'
  # 첫 동기화 — 엔진 checkout 의 engine_sync
  (cd "$d" && python3 "$W/eng/engine/build/engine_sync") > "$W/sha1-$mode.out" 2>&1; rc=$?; show "$W/sha1-$mode.out"
  expect_eq "sha($mode) 첫 동기화 exit 0" 0 "$rc"
  expect_grep "sha($mode) — 갱신 줄" "엔진 없음 → $V\($mode\) 갱신" "$W/sha1-$mode.out"
  expect "sha($mode) — .mawf/WORKFLOW.md = 엔진 판" cmp -s "$W/eng/engine/WORKFLOW.md" "$d/.mawf/WORKFLOW.md"
  vf="$d/ENGINE_VERSION"; [ "$mode" = docs ] && vf="$d/.mawf/ENGINE_VERSION"
  expect_eq "sha($mode) — 판의 ENGINE_VERSION = $V" "$V" "$(cat "$vf" 2>/dev/null)"
  expect_eq "sha($mode) — 받은 판 기록(.mawf/ENGINE_REF) = sha" "$SHA" "$(cat "$d/.mawf/ENGINE_REF" 2>/dev/null)"
  (cd "$d" && git add -A && git commit -qm "sha sync")
  mv "$W/eng-bare.git" "$W/eng-bare.off"                       # 원격을 치워 네트워크(가져오기)가 없음을 보인다
  sync_cmd="python3 .mawf/engine_sync"; [ "$mode" = full ] && sync_cmd="python3 build/engine_sync"
  (cd "$d" && $sync_cmd) > "$W/sha2-$mode.out" 2>&1; rc=$?; show "$W/sha2-$mode.out"
  mv "$W/eng-bare.off" "$W/eng-bare.git"
  expect_eq "sha($mode) 같은 sha 재실행(원격 없음) exit 0" 0 "$rc"
  expect_grep "sha($mode) 재실행 — 「변경 없음」(가져오지 않음)" '변경 없음' "$W/sha2-$mode.out"
  expect_nogrep "sha($mode) 재실행 — 「닿지 못함」 없음" '닿지 못함' "$W/sha2-$mode.out"
  expect_eq "sha($mode) 재실행 — 작업 트리 무변경" "" "$(git -C "$d" status --porcelain)"
done
# 다른 sha(예전 판) 로 바꾸면 다시 받는다 — 판 이동이 동작하는지
git -C "$W/eng" commit -q --allow-empty -m "다음 판(시험)"; git -C "$W/eng" push -q "$W/eng-bare.git" HEAD:refs/heads/main 2>/dev/null || git --git-dir="$W/eng-bare.git" fetch -q "$W/eng" HEAD:refs/heads/main
SHA2=$(git -C "$W/eng" rev-parse HEAD)
manifest "$W/sha-docs" "$W/eng-bare.git" "$SHA2" docs 'roles: {mode: open-channel}'
(cd "$W/sha-docs" && python3 .mawf/engine_sync --check) > "$W/sha3c.out" 2>&1; show "$W/sha3c.out"
expect_grep "--check — 받은 커밋 ≠ ref 안내" "동기화 필요\(docs\) — 받은 커밋 ${SHA:0:12} ≠ ref ${SHA2:0:12}" "$W/sha3c.out"
expect_eq "--check 는 쓰지 않음(기록 그대로)" "$SHA" "$(cat "$W/sha-docs/.mawf/ENGINE_REF" 2>/dev/null)"
(cd "$W/sha-docs" && python3 .mawf/engine_sync) > "$W/sha3.out" 2>&1; show "$W/sha3.out"
expect_eq "sha 바꾸면 다시 받아 기록 갱신" "$SHA2" "$(cat "$W/sha-docs/.mawf/ENGINE_REF" 2>/dev/null)"
expect_grep "sha 바꾼 갱신 — 바뀐 파일에 .mawf/ENGINE_REF" '갱신 — 바뀐 파일 .*\.mawf/ENGINE_REF' "$W/sha3.out"
# 태그 ref 는 지금 그대로 — 버전 비교(같으면 네트워크 없이 「변경 없음」)
manifest "$W/sha-docs" "$W/eng-bare.git" "v$V" docs 'roles: {mode: open-channel}'
(cd "$W/sha-docs" && python3 .mawf/engine_sync) > "$W/sha4.out" 2>&1; show "$W/sha4.out"
expect_grep "태그 ref(v$V) — 버전이 같으면 「변경 없음」" "매니페스트 ref v$V 와 같음, 변경 없음" "$W/sha4.out"
finish
