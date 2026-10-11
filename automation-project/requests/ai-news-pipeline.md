# Automation Request: ai-news-pipeline

## Slug
ai-news-pipeline

## Goal
Pipeline يجمع أخبار الذكاء الاصطناعي من RSS عامة، ينظفها ويوحدها، يزيل التكرار ببصمة ثابتة، يصنفها بقواعد محددة، يجهز مرحلة AI مستقلة (معطلة بدون Credentials)، يحفظ النتائج محليًا بدون تكرار، ويعمل كل 30 دقيقة (غير مفعل حتى الموافقة). بلا Telegram/Email/نشر خارجي.

## Trigger
schedule

## Schedule
every 30 minutes (schedule node + manual trigger for testing, workflow stays inactive)

## Feed URL
https://www.theguardian.com/technology/artificialintelligenceai/rss

## Inputs
- Public RSS feeds (Guardian AI, MIT Technology Review), no auth
- Existing local date file for cross-run dedupe

## Steps
- Load sources config (single edit point)
- Fetch each feed (per-source error isolation)
- Normalize to fixed schema
- Deduplicate by fingerprint (URL + normalized title)
- Filter malformed/low-quality items
- Classify with deterministic rules (honest: NOT AI-powered)
- AI enrichment stage in AI_DISABLED mode (extensible later)
- Shape structured output
- Store locally merged by fingerprint (idempotent)
- Build execution report

## Conditions
- Skip items with empty title AND url (quarantine)
- Keep items passing quality filter only

## External Services
- Public RSS GET requests (Guardian, MIT TR)

## Outputs
Items: title, url, source, publishedAt, description, category, importance 0-100, summary, topics, fingerprint, processedAt + execution report

## Storage
n8n_data/news-data/YYYY-MM-DD.json + backups mirror, merged by fingerprint

## Notifications
-
