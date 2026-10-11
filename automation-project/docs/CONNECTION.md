# طريقة اتصال OpenCode بـ n8n (المصادر الرسمية)

البيئة: n8n Community Self-hosted على `http://localhost:5678` — Docker، SQLite.

## 1) Server CLI — يعمل الآن بدون أي Credentials ✅ (الطريقة المعتمدة حاليًا)

الأوامر تُنفذ داخل الحاوية (التوثيق الرسمي: `docker exec <container> n8n ...`):

| المهمة | الأمر |
|---|---|
| استيراد Workflow | `docker exec n8n n8n import:workflow --input=/backups/stage/file.json` |
| تصدير الكل (Backup) | `docker exec n8n n8n export:workflow --backup --output=/backups/auto` |
| تصدير Credentials (مشفرة) | `docker exec n8n n8n export:credential --all --output=/backups/auto/credentials.json` |
| تنفيذ Workflow | `docker exec n8n n8n execute --id=<ID>` (يفشل لو السيرفر شغال — انظر `Test-ManualWorkflow.ps1`) |
| تفعيل/إيقاف | `docker exec n8n n8n update:workflow --id=<ID> --active=true/false` (**يلزم Restart بعده**) |

ملاحظات:
- أي تغيير عبر CLI (استيراد/تفعيل) **لا يسري إلا بعد `docker restart n8n`** (سلوك موثق بالتجربة).
- ملاحظة n8n الرسمية: أوامر Server CLI للاستيراد/التصدير مخطط لإيقافها مستقبلًا لصالح `n8n-cli` (بدون موعد) — لذلك كل Workflow محفوظ JSON في `workflows\` كمصدر دائم.

## 2) Public REST API — بعد إنشاء API Key (مطلوب خطوة من المستخدم) ⏳

- القاعدة: `http://localhost:5678/api/v1` — الترويسة: `X-N8N-API-KEY: <key>`
- يدير: Workflows (CRUD + activate) / Executions / Credentials / Users / Variables...
- الإنشاء من الواجهة فقط: Settings → n8n API → Create an API key (لن يخترع OpenCode مفتاحًا أبدًا).
- بعد توفير المفتاح: يُخزن **خارج الملفات** (متغير بيئة في الجلسة فقط)، ثم تُستخدم endpoints الرسمية.

## 3) n8n-cli الرسمية (للمطورين) — مستقبلًا ⏳

أداة npm من n8n (`workflow list/get/create/update/delete/activate`, `execution list/retry`, ...) — تحتاج نفس API Key. تُعتمد بعد توفير المفتاح.

## 4) ملفات JSON — المصدر الدائم للنسخ ✅

`automation-project\workflows\*.json` هو مخزن النسخ. الاستيراد لاحقًا عبر CLI أو الواجهة (Import from File).

## 5) MCP — غير معتمد حاليًا ⏸️

- عقدة MCP Trigger داخل n8n مخصصة لبناء وكلاء AI **داخل** n8n، وليست قناة لإدارة n8n من الخارج.
- أدوات مجتمعية (مثل n8n-mcp) طرف ثالث + تحتاج API Key — تُقيّم فقط إذا طُلبت صراحة.

## الخلاصة

**الآن:** ملفات JSON + Server CLI عبر `scripts\` — يعمل بالكامل بدون Credentials.
**لاحقًا (بمفتاح من المستخدم):** REST API ثم n8n-cli.
