# Test Report — ai-news-pipeline-v003 (Telegram delivery)

Workflow ID: `ai-news-pipeline-v003` | 29 nodes | Credential: `Telegram Bot - Nour` (telegramApi, UI-created via API, secret never in files)
Result: **SUCCESS — real messages delivered with interpolated article data.**

## Pipeline delta vs v002
Per chain: Shape (+`sendTelegram` bool via expression, +`tgText` prebuilt string)
→ fan-out [[Store],[Important?]] → Important? (IF boolean, proven pattern)
→ true → Send Telegram (text `={{ $json.tgText }}` pure reference).

## Tests
- Import/validate/syntax: PASS.
- Live execution: success; 2 high-importance items (both 70) sent as message_id 25, 26 to user chat.
- Selectivity: lower-importance items correctly skipped (no send).
- Reports/Store: unchanged behavior from v002 (shared static store).

## Fix 2026-10-05: no-repeat delivery (user: "same news every run")
- Root cause: Telegram branch read Shape output (current batch), so every 30-min run
  re-sent the same important articles. Store dedupe was correct; sending was not.
- Fix: Store now emits `newArticles` (fresh fingerprints only, cap 15);
  new `PickImportant G/M` nodes forward only importance>=60 AND fresh items.
- Old `Important G?/M?` IF nodes removed (number op unreliable; boolean pattern kept in docs).
- Verified live: run with zero fresh items → Pick outputs [] → Telegram never fires (correct
  suppression). Next genuinely-new important article will send exactly once.
- Note: re-import resets active=false; re-activated v003 after import (active=True verified).

## Hard-won findings (added to TROUBLESHOOTING)
1. Mixed text + `{{ }}` in telegram `text` is sent LITERALLY (no evaluation).
2. Leading-`=` JS-concat in telegram `text` is also sent literally (mode marker consumed, not evaluated).
3. Working pattern: build the full string in Set/Code (expressions evaluate there), reference it purely.
4. n8n appends a "sent automatically with n8n" footer to Telegram messages (platform behavior, harmless).
