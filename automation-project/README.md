# automation-project — إدارة n8n من OpenCode

محرك الأتمتة: n8n Community Self-hosted على **http://localhost:5678** (المشروع: `C:\Users\NOUR SOFT\n8n`).

> **Autonomous Automation Engineer:** الوثيقة المرجعية الكاملة في `docs\AUTOMATION-ENGINE.md`.
> الواجهة السريعة: `.\automation.ps1 (new|plan|validate|test|backup|list|inspect)`.

## الهيكل

- `workflows\` — نسخ JSON لكل Workflow (المصدر الدائم). لا أسرار داخلها أبدًا.
- `scripts\` — أدوات التشغيل (PowerShell).
- `docs\` — التوثيق (الاتصال، الدليل، Credentials، الأخطاء، نموذج الطلب).
- `backups\` — صادرات مؤرخة قبل أي تعديل (Workflows + Credentials مشفرة).
- `tests\` — التوقعات وقوائم الفحص.

## إنشاء Workflow جديد

1. املأ `docs\WORKFLOW-REQUEST-TEMPLATE.md` وأرسله في الشات.
2. OpenCode يولد `workflows\<id>.json` → تحقق → Backup → استيراد → اختبار فعلي.
3. يدويًا بالسكربتات:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\Validate-Workflow.ps1 -Path "workflows\my-flow.json"
powershell -ExecutionPolicy Bypass -File scripts\Import-Workflow.ps1 -Path "workflows\my-flow.json"
```

## التشغيل

- من الواجهة: افتح الـ Workflow ← **Execute workflow** (Manual) أو فعّله ونادِ Webhook.
- Manual من السطر: `powershell -ExecutionPolicy Bypass -File scripts\Test-ManualWorkflow.ps1 -Id "<id>"`

## الاختبار

- JSON صحيح ≠ نجاح. النجاح = مخرجات تنفيذ فعلية مطابقة لـ `tests\*-expected.json`.
- قائمة الفحص: `tests\e2e-checklist.md`.

## Backup / Restore

- قبل أي تعديل: `powershell -ExecutionPolicy Bypass -File scripts\Backup-Workflows.ps1 -Label "before-change"` (نسخة مؤرخة في `backups\`).
- استعادة بيانات n8n الكاملة: `powershell -ExecutionPolicy Bypass -File "C:\Users\NOUR SOFT\n8n\backup-n8n.ps1"` للنسخ، وسكربت `restore-n8n.ps1` للاسترجاع.
- استعادة Workflow واحد: أعد استيراد نسخته من `backups\` أو `workflows\` عبر `Import-Workflow.ps1`.

## إضافة Credentials

أنت تنشئها في الواجهة (التفاصيل: `docs\CREDENTIALS.md`) وتخبر OpenCode بالاسم فقط.

## التعامل مع الأخطاء

راجع `docs\TROUBLESHOOTING.md`. القاعدة: أي عملية حذف/تعديل خطرة تتطلب تأكيدك الصريح أولًا.
