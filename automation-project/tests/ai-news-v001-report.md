# Test Report — ai-news-pipeline-v001

Workflow ID: `ai-news-pipeline-v001` | Spec: `specs\ai-news-pipeline.spec.json`
Request: `requests\ai-news-pipeline.md` | Active: **false** (never activated)
Result: **SUCCESS** (5/6 pass + 1 documented engine limitation)

## TEST 1 — Normal RSS (LIVE) — PASS
- 20 Guardian AI + 10 MIT Technology Review items fetched, normalized, fingerprinted, classified.
- Schema verified (11 fields), sources attributed via hostname map, stored merged (31 total).
- Evidence: `tests\ai-news-v001-run1.json`, `run2.json`.

## TEST 2 — Duplicates (harness, exact node code) — PASS
- 10 articles (3 dup variants: case, tracking params, exact) → 7 unique, sha256 fingerprints stable.
- cyrb53 (pure JS — crypto module is sandbox-blocked, see findings).

## TEST 3 — Empty feed (harness) — PASS
- 0 in → 0 out, no crash.

## TEST 4 — Malformed articles (harness) — PASS
- Missing title+url → `_error` flagged with source+timestamp; partial items pass with defaults; no crash.

## TEST 5 — One source unavailable — DOCUMENTED NEGATIVE RESULT
- Temp workflow `ai-news-pipeline-TEST5` (bad URL variant), executed live 3× (DNS + HTTP 500).
- **Finding:** in n8n 2.39 self-hosted, a fetch-node connection failure is FATAL to the run —
  both `rssFeedRead` and `httpRequest`, both `continueRegularOutput` and `continueErrorOutput`
  (live settings verified via export). onError error-output routing does not isolate it.
- Mitigations in place: per-item/per-node error capture for everything catchable (T2–T4),
  no partial-write corruption (Store runs only on success; static store keeps last good state),
  30-min schedule auto-recovers, failures fully visible in executions.
- Temp workflow left INACTIVE; deletion needs user approval. File moved to `tests\`.
- Proposed v002 (needs approval): dual per-source chains sharing the static store (partial progress survives).

## TEST 6 — Run twice (LIVE) — PASS
- Back-to-back runs: storedTotal 31 → 31 (only genuinely new feed items merge; zero dup growth).
- 30 shaped items, all fingerprints unique.

## Build findings fixed en route
Sandbox blocks `require('crypto'/'fs')` and globals `fetch`/`URL` → pure-JS cyrb53 + `$getWorkflowStaticData` storage;
fan-out needs `main:[[A,B]]` (single output!); multi-input Merge dropped a branch → serial chain;
`new URL()` unavailable → hostname via string split; missing `}` caught by new `Test-CodeSyntax.ps1` gate.
