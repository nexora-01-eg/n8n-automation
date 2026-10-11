# AUTOMATION-ENGINE — مهندس الأتمتة المستقل (n8n Self-hosted)

المحرك: n8n 2.39.7 Community على http://localhost:5678 | المشروع: `C:\Users\NOUR SOFT\n8n\automation-project`

## 1. Architecture
Request (`.md`) → Requirement Analysis (parser + مراجعة OpenCode) → Workflow Design (spec)
→ Node Planning (templates + allowlist) → Workflow Generation (`New-WorkflowFromSpec`)
→ Static Validation (`Validate-Workflow`: JSON/nodes/connections/expressions/allowlist/BOM)
→ Code Syntax (`Test-CodeSyntax.ps1`: `node --check` لكل Code — إجباري في `Import-Workflow`)
→ Logic Harness (`Test-PipelineLogic.ps1`: تنفيذ كود العقد الحقيقي ببيانات مُجهزة)
→ Secret Detection (ضمن التحقق) → Backup (`Backup-Workflows`) → Import (`Import-Workflow`)
→ Activation عند الحاجة (CLI + restart, بموافقة) → Test (`Test-ManualWorkflow` / webhook HTTP)
→ Verification (مقارنة بالتوقع) → Report (`tests\*-report.md`).

## 2. Usage
- طلب جديد: `.\automation.ps1 new "الوصف"` ← املأ `requests\<slug>.md` ← `.\automation.ps1 plan <slug>`
- توليد: `New-WorkflowFromSpec.ps1 -Spec specs\<slug>.spec.json` ← refine ← validate ← import ← test
- مثال حي: `requests\example-news-automation.md` (خارجي — يتوقف عند الموافقة) و`requests\demo-local-summary.md` (محلي — منفذ ومختبر).

## 3. Commands (`automation.ps1`)
`new "desc"` / `plan <slug>` / `validate <file>` / `test <id>` / `backup` / `list` / `inspect <id>`.
سكربتات مباشرة في `scripts\` بنفس الأسماء + `Test-Spec` / `Show-SafetyPlan` / `New-WorkflowVersion` / `New-WorkflowScaffold`.

## 4. Workflow lifecycle
Draft (request) → Spec v001 → Generate → Refine → Validate → Safety plan → Backup → Import
→ Test → Report. النسخ: `workflows\<slug>-v001.json` (ترقيم بـ `New-WorkflowVersion.ps1`، لا استبدال بلا Backup).

## 5. Safety rules
- `Show-SafetyPlan.ps1` يعرض: Workflow/Trigger/Nodes/External services/Credentials/Data/Side effects/Actions.
- موافقة صريحة لازمة لـ: حذف Workflow أو بيانات، رسائل/إيميلات حقيقية، نشر محتوى، تعديل ملفات مهمة،
  أوامر مالية، APIs ذات تغيير خارجي، تفعيل أتمتة لها آثار حقيقية.
- آمن تلقائيًا: validation/backup/قراءة/اختبارات معزولة.
- `example-news-automation` (Telegram) متوقف عند `APPROVAL REQUIRED` — لن يُنفذ دون موافقتك.

## 6. Credentials
لا تُخترع ولا تُخفظ في أي ملف. تُنشأ في الواجهة فقط. عند الحاجة يُطبع:
`CREDENTIAL REQUIRED: service/type/reason` ويتوقف الجزء المعتمد عليها (`docs\CREDENTIALS.md`).

## 7. Testing (8 خطوات)
JSON → nodes → connections → secret scan → import → execution → output → error-path.
الدليل: `tests\e2e-checklist.md`. تقارير: `tests\*-report.md` + أدلة `*-last-run.json`.

## 8. Backup/Restore
- قبل أي تعديل: `Backup-Workflows.ps1` (تصدير `--backup` + credentials مشفرة) إلى `backups\<timestamp>-<label>\`.
- نسخة n8n الكاملة: `..\backup-n8n.ps1` / `restore-n8n.ps1`. استعادة workflow واحد = إعادة استيراد نسخته.

## 9. Templates
15 قالبًا في `templates\` (http/webhook/scheduled/email/telegram/discord/sheets/database/file/rss/ai/
transform/notifications/approval/error-handling) — مقتطفات بلا مفاتيح، تُركّب عبر المولد.
Allowlist الأنواع: `scripts\node-types-allowlist.json` (837 نوعًا من n8n المثبت).

## 10. Known limitations
1. بلا n8n API Key: لا REST API ولا `n8n-cli` (بانتظار مفتاح من Settings → n8n API).
2. تغييرات CLI تسري بعد `docker restart n8n` فقط.
3. ملفات JSON بلا BOM (n8n CLI يرفضه) — المولد والتحقق يفرضان ذلك.
4. PowerShell 5.1: سكربتات `.ps1` محفوظة UTF-8 **مع BOM**؛ `$Var` المقيّد نوعًا في `param` لا يُعاد استخدامه لكائنات.
5. `execute --id` يتعارض مع السيرفر (منفذ 5679) — الاختبار يستخدم حاوية مؤقتة مع إيقاف قصير (~40 ثانية).
6. Workflows المستوردة قبل إنشاء الـ Owner بلا مالك — النسخ JSON مصدر الحقيقة لإعادة الاستيراد.
7. مسار الخطأ يُختبر حيًا عند الإمكان، وإلا مراجعة ثابتة موثقة.
8. فشل شبكة عقد fetch (DNS/HTTP) قاتل للتشغيل في n8n 2.39 رغم `onError` (مثبت تجريبيًا) —
   التخفيف: إعادة الجدولة التلقائية + لا فساد جزئي + الرؤية الكاملة. انظر `tests\ai-news-v001-report.md`.
9. العزل الحقيقي = سلاسل مستقلة داخل Workflow واحد + مخزن static مشترك (v002):
   fan-out `main[[A,B]]` يعمل؛ Merge متعدد المداخل يسقط فرعًا؛ static data per-workflow فقط؛
   التشغيل الفاشل يُبقي كتابات الفروع المكتملة. انظر `tests\ai-news-v002-report.md`.
10. استدعاء sub-workflow يحتاج child مفعّلاً + trigger سليم؛ `readWriteFile` بلا مسار دائم هنا —
    لذلك v002 أحادي الـ Workflow. لا تفعيل لأي Schedule دون موافقة صريحة.
