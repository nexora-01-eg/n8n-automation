# Automation Request: example-news-automation

> مثال لطلب لغة طبيعية يتحول إلى Spec ثم Workflow. يتضمن Telegram → سيُظهر CREDENTIAL REQUIRED ويتوقف قبل أي إرسال حقيقي.

## Slug
example-news-automation

## Goal
جمع أخبار الذكاء الاصطناعي كل 30 دقيقة، منع التكرار، تلخيص الأخبار، تصنيفها، حفظ النتائج، وإرسال المهم إلى Telegram.

## Trigger
schedule

## Schedule
every 30 minutes

## Feed URL
https://example.com/ai-news.rss

## Inputs
- RSS feed للأخبار
- سجل الروابط السابقة (لمنع التكرار)

## Steps
- قراءة الخلاصة عبر RSS Read
- إزالة المكرر بمفتاح الرابط
- تلخيص وتصنيف محلي (Score Items)
- حفظ النتائج في Google Sheets
- إرسال المهم إلى Telegram

## Conditions
- إرسال Telegram فقط إذا important=true

## External Services
- Google Sheets
- Telegram Bot API

## Outputs
قائمة عناصر: title, link, summary, category, important, processedAt

## Storage
Google Sheets (NOOR-AI-News)

## Notifications
- Telegram message for important items
