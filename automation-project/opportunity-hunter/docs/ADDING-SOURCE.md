# Adding a source

1. Copy `backend/sources/remoteok.py` to `backend/sources/mysource.py`.
2. Set `id` (kebab, unique) and `label`. Implement:
   - `fetch()` → list of raw dicts (public URL, no auth, timeout ≤ 25s, clear errors).
   - `normalize(raw)` → dict with: source, source_item_id, url, title, description,
     posted_at (ISO or None), raw_data (small dict). Missing → 'UNKNOWN'/None, never invented.
3. Register: `from .sources.mysource import XAdapter` + `ADAPTERS['myid'] = XAdapter` in `backend/collector.py`.
4. Config: append `{ "id": "myid", "enabled": true, "max_items": 40 }` to `config/app.json` sources.
5. Rebuild + test: `docker compose up -d --build` then `.\opportunity-hunter.ps1 test`
   and a limited run: `POST /api/run {"limits": {"myid": 5}}`.
6. Verify in dashboard Sources view (status/found/added/errors).
