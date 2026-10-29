#!/usr/bin/env bash
# 하니스(일회용 러너)에서 작업자 CLI 를 설치하고 토큰 형식을 점검한다. 값은 출력하지 않는다(길이·형식만).
set -euo pipefail
npm i -g @anthropic-ai/claude-code >/dev/null && claude --version
TOK=${MAWF_RUNNER_TOKEN:-}
if [ -z "$TOK" ]; then echo "::warning::MAWF_RUNNER_TOKEN 비어 있음 — 로그인된 CLI 가 없으면 작업자가 인증 실패(실행기 장애 75)로 끝난다"; exit 0; fi
echo "토큰 길이=${#TOK} 공백문자=$(printf %s "$TOK" | tr -cd '[:space:]' | wc -c)"
case "$TOK" in
  sk-ant-oat01-*) echo "형식: 구독 OAuth 토큰(정상)" ;;
  sk-ant-api*) echo "::warning::API 키 형식 — OAuth 토큰(claude setup-token)이 아니다. API 키로 쓰려면 runner.sh 의 토큰 변수를 ANTHROPIC_API_KEY 로" ;;
  *) echo "::warning::알 수 없는 형식 — claude setup-token 출력 전체인지 확인" ;;
esac
