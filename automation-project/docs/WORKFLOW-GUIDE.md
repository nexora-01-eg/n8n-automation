# دليل بناء Workflow من وصف نصي (OpenCode)

## التدفق المعتمد: وصف → JSON → تحقق → Backup → استيراد → اختبار فعلي

1. **الوصف:** املأ `docs\WORKFLOW-REQUEST-TEMPLATE.md` (المدخلات، الخطوات، المخرجات، الجدولة/التشغيل، معالجة الأخطاء).
2. **البناء:** OpenCode يولد JSON في `workflows\<id>.json` بالقواعد:
   - `name` واضح + `id` فريد ثابت + `active:false` مبدئيًا.
   - Trigger مناسب (Manual للتجربة، Webhook/Schedule للإنتاج).
   - كل عقدة `name` واضح، و`settings.onError` للعقد الحرجة (`continueRegularOutput` أو `continueErrorOutput` حسب الحالة).
   - عقدة Code تُغلف منطقها بـ `try/catch` وتُخرج `{success, ...}` + `console.log` للتتبع.
   - `settings.timezone: Africa/Cairo`.
   - **ممنوع:** أي Secret داخل الباراميترات — المراجع لـ Credentials فقط.
3. **التحقق:** `scripts\Validate-Workflow.ps1 -Path <file>` (يجب: VALIDATION PASSED).
4. **Backup:** تلقائي داخل `Import-Workflow.ps1` (تصدير شامل مؤرخ في `backups\`).
5. **الاستيراد:** `scripts\Import-Workflow.ps1 -Path <file>` (استيراد + Restart + فحص صحة).
6. **الاختبار الفعلي:**
   - Manual Trigger → `scripts\Test-ManualWorkflow.ps1 -Id <id>` (تنفيذ حقيقي، مخرجات JSON تُقارن بالتوقع).
   - Webhook → استدعاء HTTP مباشر للرابط ومقارنة الرد.
   - JSON صحيح وحده **لا يعني النجاح** — يلزم مخرجات تنفيذ فعلية.

## معايير كل Workflow

واضح الأسماء • قابل لإعادة التشغيل (Idempotent: نفس الدخل = نفس الخرج، بلا آثار جانبية مكررة) •
معالجة أخطاء • تسجيل (Logging) عند الحاجة • بلا Secrets • يستخدم n8n Credentials •
نسخة JSON في `workflows\` • لا حذف إلا بتأكيد صريح.
