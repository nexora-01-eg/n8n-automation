# Templates — مكتبة مقتطفات Nodes قابلة لإعادة الاستخدام

15 قالبًا في هذا المجلد (JSON لكل فئة). كل قالب يحتوي: `nodes` + `connections` + `placeholders` (بصيغة `{{TOKEN}}`) + `credentialsRequired`.

## القواعد

- القوالب **مقتطفات** تُركّب داخل Workflow كامل عبر `New-WorkflowFromSpec.ps1` أو OpenCode — لا تُستورد مباشرة.
- أنواع الـ Nodes كلها من n8n المثبت (2.39.7) — راجع `scripts\node-types-allowlist.json`.
- أي قالب يحتاج خدمة خارجية يحمل `credentials: {<type>: {id: null, name: PLACEHOLDER}}` — يُستكمل في الواجهة فقط، ولا توجد مفاتيح حقيقية هنا أبدًا.
- الفئات: http-api / webhook / scheduled / email / telegram / discord / google-sheets / database / file-processing / rss-news / ai-processing / data-transformation / notifications / approval / error-handling.
