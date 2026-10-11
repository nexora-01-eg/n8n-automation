# Test Report — ai-news-pipeline-v002 (dual independent chains)

Workflow ID: `ai-news-pipeline-v002` | 25 nodes | Spec: `specs\ai-news-pipeline-v002.spec.json`
Active: **false** (never activated) | Result: **ALL 8 TESTS DOCUMENTED**

## Architecture
Manual/Schedule → fan-out `main[[FetchG, FetchMIT]]` → two fully independent chains
(fetch→attach→normalize→dedupe→filter→quarantine/classify→AI_DISABLED→shape→store→report)
→ shared per-workflow static store (`newsDates`, merged by fingerprint).

## T1 — A success / B success (LIVE) — PASS
- 20 Guardian + 10 MIT shaped, stored, both per-chain reports success.
- Evidence: `tests\ai-news-v002-t1.json`.

## T2 — A Guardian ok / B DNS dead (LIVE, temp T2X) — PASS (data isolation proven)
- Run status error (honest red), but Guardian chain completed: static store holds 20 Guardian items.
- Verified via read-only DB snapshot (no production writes).

## T3 — A Guardian ok / B HTTP 500 (LIVE, temp T3X) — PASS
- Same pattern: Guardian 20 stored, run red, no corruption.

## T4 — Empty feed (harness on v002 nodes) — PASS (0→0, no crash)

## T5 — Malformed items (harness on v002 Normalize) — PASS (flagged + partials pass)

## T6 — Cross-source duplicates — PASS
- Harness 10→7 (stable cyrb53); live: 30 shaped all unique fingerprints, merged total correct.

## T7 — Idempotency — PASS
- Same-day rerun: storedTotal 60→60 (zero growth). Cross-date growth = daily partition by design
  (each date key holds that day's snapshot; same fingerprints merge within a date).

## T8 — Both sources dead (LIVE, temp T8X) — PASS
- Run errors, temp store stays EMPTY (0 items), v002 production store untouched (30→60 history intact).
- No corruption, no partial writes, no report fabricated.

## Proven engine constraints (n8n 2.39.7, 10+ experiments)
1. Node-level network throw (DNS/HTTP) is fatal to the run despite `onError` (both modes, both fetch node types).
2. `$getWorkflowStaticData('global')` is PER-WORKFLOW (cross-workflow read returned null) — hence single-workflow dual chains, not sub-workflows.
3. Sub-workflow calls need ACTIVE children + healthy trigger nodes (probe maze documented; not used).
4. `readWriteFile` has no durable writable path here (.n8n denied, /backups denied, /home/node ephemeral) — hence static store, not files.
5. Merge multi-input drops branches (index semantics) — hence fan-out + serial chains, no Merge node.
6. Failed runs still commit completed branches' static writes (T2/T3 stores prove it) — partial progress survives red status.
