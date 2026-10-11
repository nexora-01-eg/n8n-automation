# Troubleshooting

- **API down**: `.\opportunity-hunter.ps1 doctor`. If container stopped: `docker compose up -d`.
- **0 added, many dups**: normal on re-runs (same feed). If FIRST run adds ~0 with fresh feeds,
  check fingerprinting (query: same URL collapsing?) — fixed once for HN `?id=` URLs.
- **Source failed**: Sources view shows error_type/message. HN Firebase is occasionally slow;
  adapter timeout is 25s/item; next scheduled run recovers automatically.
- **Dashboard blank**: hard-refresh (Ctrl+F5); check `/api/health` first.
- **n8n can't reach API**: n8n uses `http://host.docker.internal:8091` (works from Docker Desktop).
  Test from n8n container: `docker exec n8n wget -qO- http://host.docker.internal:8091/api/health`.
- **Port 8091 busy**: change mapping in `docker-compose.yml`, rebuild.
- **DB locked**: WAL mode + 30s timeout; concurrent runs are serialized by ThreadingHTTPServer GIL in practice.
  Never edit `opps.db` by hand while running — stop the stack first.

# AI later (`AI-LATER.md` summary)
`backend/ai.py` exposes `AIProvider.enrich(item)`. v001 returns `AI_DISABLED` passthrough.
To enable: implement provider (local LLM/OpenAI/Gemini) honoring the UNKNOWN rule + wire credentials
via environment (never files), then set `config/app.json` ai.mode. Collector survives AI failure by design.
