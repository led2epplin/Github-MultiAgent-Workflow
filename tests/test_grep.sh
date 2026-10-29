#!/usr/bin/env bash
# 고유값 grep(ORDER-26A 4) — 엔진 디렉터리(engine/)에 세션 이름·벤더·이슈·댓글 ID 가 없어야 한다. 역할로만 기술(WORKFLOW.md 머리).
# 사용: bash tests/test_grep.sh <임시폴더> [대상 엔진 저장소]
set -u
. "$(dirname "$0")/lib.sh" "$@"
tc_head "엔진 디렉터리 고유값 0건"
PAT='cowork1|code1|Claude|Codex|6444258221|#168'
grep -rn -E "$PAT" "$T/engine" --exclude-dir=__pycache__ > "$W/hits.txt"
echo "검사식: grep -rn -E '$PAT' engine/"; echo '```'; sed "s|$T/||" "$W/hits.txt"; echo '```'
expect_eq "engine/ 에서 고유값 0건" 0 "$(wc -l < "$W/hits.txt")"
grep -rn -i -E 'anthropic|openai|gemini|claude -p|npm i -g|_OAUTH_TOKEN|hj2' "$T/engine" --exclude-dir=__pycache__ > "$W/vend.txt"
echo '```'; sed "s|$T/||" "$W/vend.txt"; echo '```'
expect_eq "engine/ 에 벤더 CLI·토큰 이름·프로젝트 고유 이름 0건(어댑터·매니페스트로 이동)" 0 "$(wc -l < "$W/vend.txt")"
finish
