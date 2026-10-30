# 하니스 v2 — V 모델 검수 파이프라인

정본 설계안(원칙·역할·관문·검토 항목 R1~R6/T1~T5·도구 라이선스·비용 배치·도입 순서): Claude Docs 「하니스 v2 설계안 — V 모델 검수 파이프라인」 https://claude.ai/artifact/HJFnUXvcpyAaNa14DEsksC
이 파일은 흐름도 정본이다 — 설계가 바뀌면 같은 PR 에서 이 그림도 고친다. 역할은 세션·벤더 이름이 아니라 역할로 적고, 현재 배정은 괄호에 둔다.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "15px", "lineColor": "#8a8780", "clusterBkg": "#ffffff", "edgeLabelBackground": "#ffffff"}, "flowchart": {"wrappingWidth": 420, "nodeSpacing": 46, "rankSpacing": 44, "curve": "basis", "padding": 14}}}%%
flowchart TD
  subgraph P1["📋 명세 — 코드보다 먼저"]
    REQ["<b>① 요구사항 REQ + RT 의 TC</b><br/>Orchestrator Agent · 큰 기능은 사용자 승인"]
    SPEC["<b>② 설계 명세 ADS · UDS + TC</b><br/>Developer Agent"]
    G1{{"<b>③ 명세 리뷰</b> → 🏷 Spec-Review +1<br/>Reviewer Agent ×2 (Codex·code)"}}
  end
  subgraph P2["🛠 개발"]
    CODE["<b>④ 코드 구현</b><br/>Developer Agent · PR (draft 금지)"]
    G2{{"<b>⑤ 코드 리뷰 R1~R6</b> → 🏷 Code-Review +2<br/>⚙ 도구 관문 먼저 → Reviewer Agent ×2"}}
  end
  subgraph P3["🧪 시험"]
    TCC["<b>⑥ 시험 코드 RT · IT · UT</b><br/>TC-Maker Agent (Developer 와 다른 Agent)"]
    G3{{"<b>⑦ 시험 리뷰 T1~T5</b> → 🏷 TC-Review +1<br/>TC-Reviewer Agent ×2 (Codex·code)"}}
    G4{{"<b>⑧ 시험 실행</b> → 🏷 Verified +1<br/>⚙ Tester = 스크립트 · 커버리지·뮤테이션"}}
  end
  subgraph P4["🏁 마감"]
    DONE(["<b>⑨ merge → main 재확인 → close</b><br/>Quality Reviewer Agent · 🏷 라벨 4개 확인"])
  end
  subgraph PF["🔁 실패 처리"]
    RETRY["<b>재시도</b><br/>Developer Agent 가 같은 PR 에 수정<br/>→ 실패한 관문부터 다시"]
    STRAND["<b>🚩 좌초 + 사용자 보고</b><br/>티켓 stranded · 자동 재개발 없음"]
  end

  REQ --> SPEC
  SPEC --> G1
  G1 -->|통과| CODE
  CODE --> G2
  G2 -->|통과| TCC
  TCC --> G3
  G3 -->|통과| G4
  G4 -->|통과| DONE
  G1 -.->|실패| RETRY
  G2 -.->|실패| RETRY
  G3 -.->|실패| RETRY
  G4 -.->|실패| RETRY
  RETRY ==>|같은 티켓 3회 실패| STRAND

  classDef orch fill:#efedff,stroke:#6b5bd6,stroke-width:2px,color:#2a2357
  classDef dev fill:#e7f1fb,stroke:#2b6fd6,stroke-width:2px,color:#12305e
  classDef review fill:#fdf1d8,stroke:#d18a00,stroke-width:2px,color:#5a3b00
  classDef maker fill:#e5f4e4,stroke:#2e8b57,stroke-width:2px,color:#123d25
  classDef tester fill:#dff5f5,stroke:#0f8b8d,stroke-width:2px,color:#0b3f40
  classDef quality fill:#fff4c2,stroke:#b8860b,stroke-width:3px,color:#4a3600
  classDef retry fill:#fdeee6,stroke:#d9622b,stroke-width:2px,color:#5a2408
  classDef strand fill:#fbe3e3,stroke:#c43c3c,stroke-width:2.5px,color:#5c1111
  class REQ orch
  class SPEC,CODE dev
  class G1,G2,G3 review
  class TCC maker
  class G4 tester
  class DONE quality
  class RETRY retry
  class STRAND strand

  style P1 fill:#f8f7ff,stroke:#c9c2f2,stroke-width:1.5px,color:#2a2357
  style P2 fill:#f5f9fe,stroke:#b5cfee,stroke-width:1.5px,color:#12305e
  style P3 fill:#f4faf4,stroke:#b6dbbb,stroke-width:1.5px,color:#123d25
  style P4 fill:#fffbea,stroke:#e8d27a,stroke-width:1.5px,color:#4a3600
  style PF fill:#fff7f5,stroke:#f0c4b3,stroke-width:1.5px,color:#5a2408

  linkStyle 0,1,3,5 stroke:#8a8780,stroke-width:1.5px
  linkStyle 2,4,6,7 stroke:#2e8b57,stroke-width:2.5px,color:#2e8b57
  linkStyle 8,9,10,11 stroke:#d9622b,stroke-width:1.8px,stroke-dasharray:6 4,color:#d9622b
  linkStyle 12 stroke:#c43c3c,stroke-width:3px,color:#c43c3c

  subgraph LEG["색 = 역할"]
    direction LR
    L1["Orchestrator"]:::orch ~~~ L2["Developer"]:::dev ~~~ L3["Reviewer"]:::review ~~~ L4["TC-Maker"]:::maker ~~~ L5["Tester"]:::tester ~~~ L6["Quality"]:::quality
  end
  style LEG fill:#ffffff,stroke:#dddddd,stroke-width:1px,color:#555555
  LEG ~~~ REQ
```
