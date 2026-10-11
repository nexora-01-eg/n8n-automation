# Test Report — demo-local-summary v001

Workflow ID: `demo-local-summary-v001` | Spec: `specs\demo-local-summary.spec.json`
Request: `requests\demo-local-summary.md` | Evidence: `tests\demo-local-v001-last-run.json`
Date: 2026-09-18 | Result: **SUCCESS**

## Pipeline
Request → Spec (parser + review) → Safety plan (SAFE, no approval) → Generator (8 nodes)
→ OpenCode refinement (real sample/classify logic) → Static validation → Backup → Import → Test ×3 → Report

## Test steps (PHASE 6)
1. **JSON validation** — PASS (`Validate-Workflow.ps1`: valid JSON, name/nodes/connections present)
2. **Node validation** — PASS (8/8 types in installed allowlist, n8n 2.39.7, 837 types)
3. **Connection validation** — PASS (all targets exist; true/false branches wired)
4. **Secret scan** — PASS (no hardcoded secrets; no credentials referenced)
5. **Import test** — PASS (`Successfully imported 1 workflow`, restart + healthz ok)
6. **Execution test** — PASS ×3 (`status: success`, isolated `compose run` execution)
7. **Output validation** — PASS:
   - Step 1 emits 4 items (incl. 1 duplicate link)
   - Step 2 dedupes 4→3, classifies ai/ai/sports, sets important flags
   - IF true branch: 2 important items; false branch: 1 sports item (both branches executed)
   - Shape Output: 2 items with title/link/category/important(Boolean)/processedAt
8. **Error-path test** — PARTIAL: Code nodes wrap logic in try/catch returning `{success:false, error}`
   and carry `onError: continueRegularOutput`; false-branch executed live. No live bad-input firing
   (would require destructive input mutation) — static-verified, documented as limitation.

## Issues found & fixed during build
- Generator quoted `$json` in double-quoted strings (PS expansion) → fixed with single-quote/backtick escaping.
- Generator scaffold JS was syntactically invalid → rewrote template; execution test caught it (pipeline works as designed).
- `Out-File -Encoding utf8` writes BOM which n8n CLI import rejects → BOM-less writes + validator BOM guard.
- Docker Desktop was stopped mid-session (external) → restarted; n8n auto-resumed via restart policy.
