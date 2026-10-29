# 엔진 시험 공통 — tests/*.sh · tests/defects/*.sh 가 source 한다. 인수: <임시폴더> [대상 엔진 저장소(기본 이 저장소)]
#   대상을 주면 그 판의 엔진을 검사한다(예: 고치기 전 판을 git archive 로 내보낸 폴더 — TC 가 실패하는지 확인할 때).
#   외부 접속 없음: 엔진 「원격」 은 대상 판을 커밋한 로컬 bare 저장소다.
ENG_SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
. "$ENG_SRC/tests/lib_assert.sh"
W=${1:?임시 작업 폴더}
T=$(cd "${2:-$ENG_SRC}" && pwd) || { echo "대상 저장소 없음: $2"; exit 2; }
rm -rf "$W"; mkdir -p "$W"; W=$(cd "$W" && pwd)
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_NOSYSTEM=1 HOME="$W/home"; mkdir -p "$HOME"; git config --global init.defaultBranch main; git config --global advice.detachedHead false
unset TICKET HARNESS_RUNNER MAWF_ENGINE_SRC MAWF_ROOT AGENT_NAME AGENT_ROLE
tc_head() { echo "# $1"; echo; echo "대상: $([ "$T" = "$ENG_SRC" ] && echo '이 저장소(작업 트리)' || echo "$T") · 엔진 $(cat "$T/ENGINE_VERSION") · $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo; }
# engine_remote <폴더> — 대상 판(작업 트리 그대로)을 커밋한 git 저장소 + 태그 v<ENGINE_VERSION>. 엔진 「원격」 대용
engine_remote() {
  local d=$1; mkdir -p "$d"; (cd "$T" && tar --exclude=.git --exclude=__pycache__ -cf - .) | tar -xf - -C "$d"
  git -C "$d" init -q && git -C "$d" add -A && git -C "$d" commit -qm "engine $(cat "$d/ENGINE_VERSION")" && git -C "$d" tag "v$(cat "$d/ENGINE_VERSION")"
}
# consumer <폴더> — 빈 소비 저장소(git, main) + 원격(bare)
consumer() {
  local d=$1; git init -q --bare "$d.remote.git"; git init -q "$d"; git -C "$d" remote add origin "$d.remote.git"
  git -C "$d" commit -q --allow-empty -m init; git -C "$d" push -q origin main
}
manifest() {  # manifest <저장소> <엔진 repo> <ref> <mode> [roles 블록]
  printf 'engine:\n  repo: %s\n  ref: %s\nmode: %s\n%s\n' "$2" "$3" "$4" "${5:-roles: {\}}" > "$1/.mawf.yaml"
}
ROLES_OK='roles:
  confirmed: "2026-10-29 23:00 시험 확정 — 근거: 시험"
  table:
    orchestrator: {sessions: "대화형 세션", count: 1, orders_from: [user]}
    worker: {sessions: "작업자 계열", count: 2, orders_from: [orchestrator, user]}'
