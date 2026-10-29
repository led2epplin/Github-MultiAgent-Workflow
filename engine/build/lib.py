"""엔진 공용 함수 — 티켓·frontmatter·경로. 표준 라이브러리 + PyYAML. 도메인 상수는 domain/ 에 둔다."""
from __future__ import annotations
import os, re, sys, json, hashlib, datetime
from pathlib import Path
import yaml

ROOT = Path(os.environ.get("HJ_ROOT") or Path(__file__).resolve().parent.parent)
TICKET_STATES = ["open", "hold", "doing", "review", "done", "stranded"]   # hold = 사람 입력 대기(ready 제외)
TICKET_TYPES = ["task", "card", "problem", "review", "change", "process", "source", "smoke", "defect"]   # defect = 결함 1건(tc 필수, WORKFLOW.md §5)
LEASE_MIN_DEFAULT = int(os.environ.get("MAWF_LEASE_MIN", "90"))   # claim 임대 기본(분) — 티켓 limits.lease_min 이 우선
TZ_HOURS = int(os.environ.get("HJ_TZ_HOURS", "9"))


def now(plus_min: int = 0) -> str:
    t = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=TZ_HOURS))) + datetime.timedelta(minutes=plus_min)
    return t.strftime("%Y-%m-%d %H:%M")


def today() -> str:
    return now()[:10]


def rel(p: Path | str) -> str:
    p = Path(p)
    try:
        return str(p.resolve().relative_to(ROOT.resolve()))
    except ValueError:
        return str(p)


def read_text(p: Path | str) -> str:
    return Path(ROOT, p).read_text(encoding="utf-8")


def split_frontmatter(text: str):
    """---\nyaml\n---\nbody → (dict, body). 머리말이 없으면 ({}, text)."""
    if not text.startswith("---"):
        return {}, text
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    if not m:
        return {}, text
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        raise ValueError(f"frontmatter YAML 오류: {e}")
    return fm, m.group(2)


def sections(body: str) -> dict[str, str]:
    """'## 제목' 단위로 본문을 나눈다."""
    out, cur, buf = {}, "_head", []
    for line in body.splitlines():
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            out[cur] = "\n".join(buf).strip()
            cur, buf = m.group(1).strip(), []
        else:
            buf.append(line)
    out[cur] = "\n".join(buf).strip()
    return out


# ---------- tickets ----------
def ticket_path(tid: str) -> Path | None:
    for st in TICKET_STATES:
        p = ROOT / "tickets" / st / f"{tid}.yaml"
        if p.exists():
            return p
    return None


def ticket_state(tid: str) -> str | None:
    p = ticket_path(tid)
    return p.parent.name if p else None


def load_ticket(tid: str) -> dict:
    p = ticket_path(tid)
    if not p:
        raise FileNotFoundError(f"티켓 없음: {tid}")
    t = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    t["_path"] = str(p)
    t["_state"] = p.parent.name
    return t


def save_ticket(t: dict, state: str | None = None) -> Path:
    t = dict(t)
    old = Path(t.pop("_path", "")) if t.get("_path") else None
    old_state = t.pop("_state", None)
    state = state or old_state or "open"
    p = ROOT / "tickets" / state / f"{t['id']}.yaml"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(yaml.safe_dump(t, allow_unicode=True, sort_keys=False, width=100), encoding="utf-8")
    if old and old.exists() and old != p:
        old.unlink()
    return p


def all_tickets() -> list[dict]:
    out = []
    for st in TICKET_STATES:
        d = ROOT / "tickets" / st
        if not d.exists():
            continue
        for p in sorted(d.glob("*.yaml")):
            t = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
            t["_path"], t["_state"] = str(p), st
            out.append(t)
    return out


def new_ticket_id(seed: str) -> str:
    h = hashlib.sha1(f"{seed}|{datetime.datetime.now().isoformat()}".encode()).hexdigest()[:6]
    return f"T-{h}"


def lease_min(t: dict) -> int:
    return int((t.get("limits") or {}).get("lease_min") or LEASE_MIN_DEFAULT)


def lease_expired(t: dict) -> bool:
    """doing 티켓의 임대가 끝났나(WORKFLOW.md §4 인계). lease_until 이 없으면 claim.at + 임대로 본다."""
    c = t.get("claim") or {}
    until = str(c.get("lease_until") or "")
    if not until and c.get("at"):
        try:
            at = datetime.datetime.strptime(str(c["at"]), "%Y-%m-%d %H:%M")
            until = (at + datetime.timedelta(minutes=lease_min(t))).strftime("%Y-%m-%d %H:%M")
        except ValueError:
            return False
    return bool(until) and until < now()


def ready_tickets() -> list[dict]:
    ts = all_tickets()
    done = {t["id"] for t in ts if t["_state"] == "done"}
    me = os.environ.get("HARNESS_RUNNER", "")
    out = []
    for t in ts:
        if t["_state"] != "open":
            continue
        want = str(t.get("runner") or "").strip()   # runner 지정 티켓은 그 이름으로 시작하는 HARNESS_RUNNER 만 집는다
        if want and not me.startswith(want):
            continue
        if all(b in done for b in (t.get("blocked_by") or [])):
            out.append(t)
    out.sort(key=lambda t: (int(t.get("priority") or 2), str(t.get("created") or ""), t["id"]))
    return out


def run_tc(t: dict, timeout: int | None = None) -> tuple[int, str]:
    """티켓의 tc(재현 TC)를 돌린다 — (종료코드, 출력 끝 몇 줄). 규약: <tc> <임시폴더> (WORKFLOW.md §5). 2 = tc 없음/파일 없음."""
    import subprocess, tempfile
    tc = str(t.get("tc") or "").strip()
    if not tc:
        return 2, "tc 없음"
    p = ROOT / tc
    if not p.is_file():
        return 2, f"tc 파일 없음: {tc}"
    with tempfile.TemporaryDirectory() as td:
        w = os.path.join(td, "w")
        cmd = ["bash", str(p), w] if p.suffix == ".sh" else ([sys.executable, str(p), w] if p.suffix == ".py" else [str(p), w])
        try:
            r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                               timeout=timeout or int(os.environ.get("MAWF_TC_TIMEOUT", "900")))
        except subprocess.TimeoutExpired:
            return 124, f"tc 시간 초과: {tc}"
    tail = "\n".join((r.stdout + r.stderr).strip().splitlines()[-5:])
    return r.returncode, tail


def iter_md(sub: str):
    d = ROOT / sub
    if not d.exists():
        return
    for p in sorted(d.rglob("*.md")):
        if p.name.startswith("_") or "/_" in str(p):
            continue
        yield p


def die(msg: str, code: int = 1):
    print(msg, file=sys.stderr)
    sys.exit(code)
