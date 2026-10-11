# Backup & Restore

## What
- `.\opportunity-hunter.ps1 backup` creates `backups/<timestamp>/` with: `opps.db*` + n8n workflow export + `app.json`.
- Retention: last 10 (older removed; never silently beyond that without approval).

## Restore (DB)
1. Stop the stack: `docker compose stop` (in `opportunity-hunter/`).
2. Copy `backups/<ts>/opps.db*` over `database/`.
3. Start: `docker compose up -d`. Verify: `.\opportunity-hunter.ps1 doctor`.

## Restore (workflow)
UI → Import from File → `backups/<ts>/workflow.json`, or via project's `Import-Workflow.ps1`.

## Full disaster restore
The n8n-level `backup-n8n.ps1` also covers the whole instance (separate schedule).
