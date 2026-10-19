# Architecture — Sakeena

## قاعدة الفصل

الـ Flutter frontend لا يستورد أي HTTP client أو كود PostgreSQL أو تفاصيل backend. والـ backend لا يعرف Widgets أو Flutter models. التواصل المستقبلي يتم عبر DTOs/Sync Protocol موثقة.

## Frontend

```text
lib/
├── main.dart                         # نقطة تشغيل فقط
├── app/                              # composition root + routing
├── core/                             # theme, storage, errors, platform adapters
├── domain/
│   ├── entities/                     # Devotion, Plan, CounterEvent...
│   └── repositories/                # interfaces فقط
├── data/
│   ├── content/                     # قراءة حزم JSON/manifest
│   ├── local/                        # SQLite repositories + migrations
│   └── repositories/                # implementations
└── features/
    ├── home/
    ├── library/
    ├── reader/
    ├── plans/
    ├── personal/
    └── settings/
```

`legacy_vertical_slice.dart` موجود مؤقتًا للحفاظ على النسخة المرئية العاملة أثناء التقسيم. كل feature جديد يُبنى في مجلده ولا يضيف منطقًا إلى الملف القديم.

## Content packages

الحزم ليست Dart code. تضاف كملفات JSON موقعة داخل `assets/content/packages/` أو تستورد إلى SQLite عبر package importer.

كل حزمة تحتوي `packageId`, `version`, `language`, `tradition`, `license`, `manifestHash`, `signature`, و`items[]`. إضافة دعاء جديد تعني إضافة سجل JSON أو migration importer دون لمس الواجهة.

المحتوى الموثق والمحتوى الشخصي منفصلان في النوع والجدول واللون والعلامة البصرية.

## Backend

```text
backend/
├── src/              # API/relay application
├── migrations/       # PostgreSQL schema
└── docs/             # protocol and security decisions
```

Backend مسؤول فقط عن pairing والـ relay للقطع المشفرة. لا يحوي business logic للعداد أو الخطط، ولا يقرأ النصوص الشخصية.

## قواعد الصيانة

1. الشاشة لا تستدعي SQLite مباشرة.
2. domain لا يستورد Flutter أو network.
3. repository interface في domain، implementation في data.
4. المحتوى لا يُكتب داخل Widget.
5. كل feature له state model واضح.
6. كل migration forward-only مع preflight backup.
7. لا نضيف abstraction إلا إذا كان هناك حد حقيقي بين طبقتين.
