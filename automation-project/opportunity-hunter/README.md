# Opportunity Hunter v001 — local freelance-opportunity discovery engine

**Status: built, tested with real data, n8n workflow INACTIVE (awaiting your approval).**

## What it is
Discovers real online-service opportunities from public sources (no auth, no spam, no outreach),
normalizes → dedupes → classifies → scores → stores in local SQLite, managed via local dashboard.
You review and decide; the system never contacts anyone.

## Layout
- `backend/` — API + collector + `sources/` adapters + db/classify/scoring/ai modules (stdlib only)
- `dashboard/` — static professional UI (served by the API, no build step)
- `database/` — `opps.db` (bind-mounted, persists) + `migrations/`
- `n8n/` — `opportunity-hunter-v001.json` (thin orchestrator: schedule 4h + manual → POST /api/run)
- `tests/` — unittest suite (runs inside container) + live evidence
- `backups/` — timestamped (db + workflow + config), retention: last 10
- `docs/` + `config/app.json`

## Run it
```powershell
.\opportunity-hunter.ps1 doctor      # health of everything
.\opportunity-hunter.ps1 run         # full collection now
.\opportunity-hunter.ps1 stats       # numbers
.\opportunity-hunter.ps1 backup      # timestamped backup
.\opportunity-hunter.ps1 test        # 21 unit+api tests
```
- Dashboard: http://localhost:8091 — API: http://localhost:8091/api/health
- n8n: import `n8n/opportunity-hunter-v001.json` (already imported, INACTIVE) → manual Execute or activate schedule after approval.

## Architecture decision (documented deviation)
The brief sketched per-stage n8n nodes. Implemented instead: **n8n = thin trigger** (schedule/manual → POST /api/run → report),
**backend = full pipeline**. Rationale: single implementation (no JS/Python duplication), SQLite writable only
from backend (n8n Code sandbox has no fs/require), DB as source of truth. Same functional contract.

## Docs
`docs/ARCHITECTURE.md` (full) · `ADDING-SOURCE.md` · `BACKUP-RESTORE.md` · `TROUBLESHOOTING.md` · `AI-LATER.md`
