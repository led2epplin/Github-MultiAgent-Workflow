#!/usr/bin/env python3
"""DRY_RUN 더미 작업자(예시) — type: smoke 티켓의 outputs 를 채운다. 하니스 루프 검증용."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "build"))
from lib import *  # noqa

t = load_ticket(sys.argv[1])
for o in t["outputs"]:
    p = ROOT / o
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(f"---\nid: {p.stem}\ntitle: 스모크 산출물 {p.stem}\nstatus: draft\nupdated: {today()}\n---\n\n## 본문\n하니스가 티켓을 집어 산출물을 만들고 검증·PR 까지 가는지 확인하기 위한 더미 문서다[판단].\n", encoding="utf-8")
print(f"smoke: {t['id']} outputs 작성")
