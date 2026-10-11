# استكشاف الأخطاء (مجرّبة فعليًا على هذا الجهاز)

| العرض | السبب | الحل |
|---|---|---|
| `Task Broker's port 5679 is already in use` عند `execute` | السيرفر شغال ويحجز المنفذ | استخدم `scripts\Test-ManualWorkflow.ps1` (يوقف السيرفر مؤقتًا وينفذ في حاوية مؤقتة ثم يعيده) |
| `The requested webhook ... is not registered` / `Active version not found` | الـ Workflow غير مفعّل أو التفعيل لم يُطبق | فعّل ثم **`docker restart n8n`** — تغييرات CLI لا تسري بدونه |
| `SQLITE_CONSTRAINT: NOT NULL constraint failed: workflow_entity.id` | ملف JSON بلا `id` علوي | أضف `"id": "<فريد>"` (نص، مثل `demo-hello-e2e-01`) |
| `Cannot access database.sqlite ... used by another process` عند الضغط اليدوي | قاعدة SQLite مقفولة والسيرفر شغال | استخدم `scripts\Backup-Workflows.ps1` (تصدير عبر CLI بدون إيقاف) — لا تضغط الملفات يدويًا والسيرفر يعمل |
| `NativeCommandError` من مخرجات docker في PowerShell | docker يكتب التقدم على stderr | السكربتات هنا تعالج ذلك — لا تستخدم `2>$null` مع `$ErrorActionPreference="Stop"` |
| الحاوية لا تبدأ بعد reboot | Docker Desktop لم يكتمل | افتح Docker Desktop وانتظر `docker info` يعرض `Server Version` |
| صفحة n8n تطلب Setup رغم وجود بيانات | لم يُنشأ حساب Owner بعد | أنشئه من المتصفح (مرة واحدة) — لا ينشئه OpenCode |

## قاعدة ذهبية

أي عملية قد تحذف بيانات/Workflows/Credentials → **توقف واطلب تأكيدًا صريحًا أولًا.**

## دروس ai-news-pipeline-v001 (مثبتة بالتجارب)

- `Module 'crypto' is disallowed` / `require` للمكتبات محظور في Code sandbox — استخدم JS خالص (cyrb53 للبصمات).
- `fetch` و`URL` غير موجودين في الـ sandbox — لا تجلب الشبكة من Code أبدًا.
- التخزين المحلي عبر `$getWorkflowStaticData('global')` (داخل SQLite) — لا `fs`.
- فشل اتصال DNS/HTTP في عقد fetch **قاتل للتشغيل** في n8n 2.39 رغم `onError` (مثبت بـ 8 تجارب) — التخفيف: جدولة تعيد المحاولة + لا كتابة جزئية فاسدة.
- Fan-out من عقدة أحادية المخرج = `main: [[A, B]]` وليس `[[A],[B]]`.
- دمج فرعين يحتاج `index: 0` و`index: 1` الصحيحين — راجع دائمًا.
- PowerShell يفكك المصفوفات الأحادية (`@($x)` وحيد، `ConvertTo-Json` لعنصر واحد) — ابنِ وصلات n8n كنص JSON مباشر.
- لا تُعد استخدام متغير `param` المقيّد نوعًا لكائنات (`[string]$Spec` ثم `$spec = object`).
- `node --check` عبر `Test-CodeSyntax.ps1` إجباري قبل الاستيراد (يمسك `}` ناقصة لا يمسكها فحص JSON).
- نصوص Telegram: لا تخلط نصًا مع `{{ }}` ولا JS-concat في حقل `text` (يُرسل حرفيًا) — ابنِ النص في Set/Code ثم ارجع بمرجع خالص `={{ $json.field }}`.
- n8n يُلحق تذييل "sent automatically with n8n" برسائل Telegram (سلوك المنصة).
