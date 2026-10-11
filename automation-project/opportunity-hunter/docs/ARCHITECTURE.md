# Architecture

```
                ┌─────────────┐
                │  n8n (thin) │  schedule 4h (inactive) + manual
                │  orchestr.  │  POST /api/run → report
                └──────┬──────┘
                       │  CLI ──► POST /api/run ──┐
                       │  Dashboard [Run now] ────┘
                       ▼
┌──────────────────────────────────────────────────┐
│ Backend (python:3.12-slim, stdlib only, :8091)   │
│  sources/hn.py ──┐                               │
│  sources/remoteok.py ─┴─► collector.run_collection │
│        fetch → normalize → validate → dedupe     │
│        → classify → score → store                │
│  ai.py (AI_DISABLED passthrough)                 │
│  db.py (migrations) + api.py (REST + static UI)  │
└──────────────┬───────────────────────────────────┘
               ▼
   SQLite (bind mount, WAL) ◄── backups/
```

## Key decisions (all evidence-backed this build)
1. **Single collector implementation** (backend), n8n triggers it. No logic duplication.
2. **SQLite file** as source of truth (not n8n static data — cross-workflow and opaque).
3. **Fingerprint** = sha256(norm-url-keep-identity-query | norm-title | source); near-title guard needs ≥5 tokens.
4. **norm_url keeps identity query params** (`?id=`) and strips tracking (`utm_*`, `ref`, `fbclid`…).
   (First version stripped ALL query → every HN comment collided. Fixed + tested.)
5. **Honest UNKNOWNs** — nothing invented; missing = UNKNOWN/NULL.
6. **Scores fully decomposed** in DB (7 parts + total + confidence).
7. **Per-source isolation** — one source failing never stops others (run status partial/failed, errors recorded).
8. **No secrets anywhere** — no keys, no credentials, public sources only.

## Adding a source
1. Create `backend/sources/mysource.py` with class `XAdapter(SourceAdapter)` (`id`, `fetch()`, `normalize()`).
2. Import + register in `backend/collector.py` `ADAPTERS`.
3. Add entry in `config/app.json` `sources`.
4. Rebuild (`compose up -d --build`) and run `opportunity-hunter.ps1 test`.
See `docs/ADDING-SOURCE.md`.
