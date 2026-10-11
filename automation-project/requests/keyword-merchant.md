# Automation Request: keyword-merchant

## Slug
keyword-merchant

## Goal
التاجر يدخل المجال (شنط، أحذية، أي فئة) + اسم متجره (اختياري)، والنظام يرجع أنسب الكلمات لهذا المجال: اقتراحات بحث حقيقية + توسعات تجارية + إزالة تكرار + ترتيب بالأهمية التجارية. محلي بالكامل، بلا مفاتيح، بلا إرسال خارجي إلا Google Suggest العام.

## Trigger
manual

## Schedule


## Feed URL


## Inputs
- niche (المجال، مثال: شنط)
- merchant (اسم التاجر، اختياري)

## Steps
- جلب اقتراحات Google (عربي + إنجليزي) للكلمة
- توليد توسعات تجارية (أسعار/شراء/أفضل/ماركات/مقاسات...)
- توحيد عربي وإزالة تكرار
- scoring بالنية التجارية والتخصصية
- تشكيل المخرجات مرتبة

## Conditions
-

## External Services
- Google Suggest (public GET, no auth)

## Outputs
قائمة: keyword, score, source, lang — مرتبة تنازلياً

## Storage
- (لا تخزين دائم في v001 — المخرجات عند التنفيذ)

## Notifications
-
