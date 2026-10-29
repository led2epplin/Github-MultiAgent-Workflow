# Github-MultiAgent-Workflow — 검수자 규칙(이 엔진 저장소의 PR)

## Review guidelines
- 지적은 한 건마다 `파일:줄` + 재현(명령·입력) + 기대 동작. 총평·칭찬은 쓰지 않는다.
- 결함 수정 PR: `defects/D-NNNN.md` 와 `tests/defects/D-NNNN.sh` 가 같이 있어야 한다. TC 는 고치기 전 커밋(git archive 로 내보낸 판을 대상 인수로)에서 실패하고, 고친 뒤 통과해야 한다 — 수동 확인만이면 P0.
- `bash tests/run_all.sh <임시폴더>` 가 실패 0 이어야 한다(외부 접속 없음).
- `engine/` 에 특정 세션·회사·모델·세션 ID·이슈/댓글 번호 같은 고유값 금지 — 역할(오케스트레이터·작업자·검수자·최종 리뷰어)로만. 벤더별 실행은 `adapters/`, 저장소 고유값은 소비 저장소 `.mawf.yaml`.
- 다중 세션 위반은 P0: claim 경합(먼저 push 된 claim 만 산다), 임대 인계(남이 인계한 티켓의 결과 확정·상태 전이 금지), 멱등(같은 명령 두 번 = 같은 상태), 역할표 게이트(미정·철회·open-channel 이면 claim 없음).
- defect 티켓은 `tk close`(TC 재실행) 경로로만 done. 공통 규칙 본문은 `engine/WORKFLOW.md`.
