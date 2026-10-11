# إضافة Credentials (يدويًا في الواجهة — OpenCode لا يخترع مفاتيح)

## لماذا يدوي؟

بيانات الاعتماد أسرار. القاعدة: **OpenCode لا ينشئ Credential ولا يطلب قيمته ولا يخزنه في ملفات.**
أنت تنشئه في الواجهة، وOpenCode يشير إليه بالاسم فقط داخل الـ Workflow.

## الخطوات (في http://localhost:5678 بعد إنشاء حساب الـ Owner)

1. افتح الـ Workflow في المحرر → اختر العقدة (مثلًا HTTP Request) → حقل Credential → **Create New**.
2. اختر النوع وأدخل القيم السرية → **Save** (تُحفظ مشفرة بمفتاح `N8N_ENCRYPTION_KEY` في `database.sqlite`).
3. أعطِ الـ Credential اسمًا واضحًا (مثلًا `GitHub API - Nour`) وأخبر OpenCode بالاسم.
4. OpenCode يضع في JSON مرجعًا فقط: `"credentials": {"githubApi": {"id": null, "name": "GitHub API - Nour"}}` — ثم تربطه أنت من الواجهة، أو يُستورد والربط يُستكمل يدويًا.

## قواعد

- ممنوع `--decrypted` في أي تصدير (النسخ الاحتياطي مشفر دائمًا).
- ملفات JSON المصدّرة قد تحتوي **أسماء** Credentials — راجعها قبل المشاركة (تحذير n8n الرسمي).
- عقد HTTP المبنية من cURL قد تحمل ترويسات auth — طهّرها قبل الحفظ.
- **API Key الخاص بـ n8n نفسه** (Settings → n8n API): أنشئه أنت عندما تطلب منك ذلك، وسلّمه للجلسة فقط (لا يُحفظ في ملف).
