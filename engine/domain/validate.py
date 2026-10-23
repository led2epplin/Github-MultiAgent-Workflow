#!/usr/bin/env python3
"""도메인 검증기(예시) — build/validate 가 같은 인수로 호출한다. 프로젝트에 맞게 바꿔 쓴다.
기본 동작: --ticket 이면 outputs 의 .md 파일이 frontmatter(id·title·status) 를 갖고 id == 파일명인지 검사."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "build"))
from lib import *  # noqa

E = []
argv = sys.argv[1:]
targets = []
if "--ticket" in argv:
    t = load_ticket(argv[argv.index("--ticket") + 1])
    targets = [ROOT / o for o in t.get("outputs") or []]
elif "--all" in argv or not argv:
    targets = [p for sub in ("docs", "cards", "problems", "out") for p in iter_md(sub)]
else:
    targets = [Path(a) for a in argv if not a.startswith("--")]
for f in targets:
    if not f.exists() or f.suffix != ".md":
        continue
    try:
        fm, body = split_frontmatter(f.read_text(encoding="utf-8"))
    except ValueError as e:
        E.append(f"{rel(f)}: {e}"); continue
    for k in ("id", "title", "status"):
        if k not in fm:
            E.append(f"{rel(f)}: 머리말 누락 {k}")
    if fm.get("id") and fm["id"] != f.stem:
        E.append(f"{rel(f)}: id({fm['id']}) ≠ 파일명({f.stem})")
    if len(body.strip()) < 40:
        E.append(f"{rel(f)}: 본문이 40자 미만")
for e in E:
    print("오류 " + e)
print(f"validate(domain): 오류 {len(E)} / 대상 {len(targets)}")
sys.exit(1 if E else 0)
