# domain/ — 이 프로젝트만의 것 (엔진 업데이트가 건드리지 않는 디렉터리)

| 파일 | 역할 | 호출 |
|---|---|---|
| `RULES.md` | 작업자가 지킬 내용 규칙. `CLAUDE.md` 가 `@domain/RULES.md` 로 읽는다 | 매 세션 |
| `validate.py` | 산출물 검사(스키마·참조·금지어…). `build/validate` 가 같은 인수(`--all` / `--ticket T` / 파일)로 호출하고 종료코드를 합친다 | 완료 판정 |
| `status.py` | STATUS.md 에 덧붙일 도메인 표(stdout). 없어도 됨 | status 생성 |
| `schemas/*.md` | 산출물 템플릿. 티켓 `inputs:` 에 넣어 작업자가 따라 쓰게 한다 | 티켓 |
| `smoke.py` | `DRY_RUN=1` 일 때 `type: smoke` 티켓의 outputs 를 채우는 더미 작업자. 없으면 엔진 기본(빈 md) | 스모크 |

`validate.py` 는 `build/lib.py` 를 import 해도 된다:
```python
import sys; from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "build"))
from lib import *
```
종료코드 0 = 통과, 1 = 오류. 출력은 한 줄에 하나 `오류 <파일>: <내용>` / `권고 …`.
