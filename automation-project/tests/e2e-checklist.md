# E2E Checklist — تُطبق على كل Workflow قبل اعتباره ناجحًا

- [ ] `Validate-Workflow.ps1` → VALIDATION PASSED (بلا أسرار داخل الملف)
- [ ] Backup تلقائي تم (مجلد مؤرخ في `backups\`)
- [ ] `Import-Workflow.ps1` → IMPORT DONE + `healthz = ok`
- [ ] تنفيذ فعلي تم (Manual عبر `Test-ManualWorkflow.ps1` / Webhook عبر HTTP / زر Execute في الواجهة)
- [ ] المخرجات الفعلية مطابقة للمتوقع (`tests\*-expected.json`)
- [ ] إعادة التشغيل تعطي نفس النتيجة (Idempotent) — نفّذ مرتين وقارن
- [ ] مسار الخطأ مُختبر (أدخل دخلًا سيئًا وتأكد من مخرج `{success:false,...}` بدل الانهيار)
- [ ] نسخة JSON النهائية محفوظة في `workflows\`
