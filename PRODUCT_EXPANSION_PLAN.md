# خطة التوسع الإنتاجية — سكون

## الهدف
نقل سكون من Production Foundation إلى منتج قابل للنشر العام، مع الحفاظ على local-first، العربية الهادئة، وتقليل جمع البيانات.

## المسارات

### 1. Core data and trust — P0
- إكمال هجرة كل القراءات إلى SQLite repositories.
- تشفير الحقول الحساسة عند السكون، مع migration آمن وpreflight backup.
- Backup/Restore بملف `.sukoon`، معاينة قبل الدمج، رفض العبث، ونسخة rollback مؤقتة.
- حذف/تصدير البيانات من داخل التطبيق.

### 2. Calm product depth — P1
- مكتبة جلسات مصنفة: نوم، قلق، تركيز، بداية اليوم، نهاية اليوم.
- صوت طبيعي مرخّص مع تنزيل اختياري وحالة offline واضحة.
- مؤقت حر، جلسات قصيرة، وإيقاف/استئناف دون ضغط على streaks.
- تذكيرات محلية اختيارية مع fallback عند رفض الإذن.
- تقدم وصفي لا يقيس قيمة المستخدم ولا يرسل analytics.

### 3. Trusted multi-device — P1/P2
- pairing عبر QR بين جهازين يملكهـما المستخدم.
- عرض نطاق البيانات قبل الموافقة، مفاتيح عامة، revocation، وpeer expiry.
- بروتوكول idempotent resumable sync، مع tombstones وحل تعارض deterministic.
- لا cloud account ولا مشاركة تلقائية.

### 4. Accessibility and content quality — P0/P1
- تدقيق screen reader، large text، contrast، touch targets، RTL، reduced motion.
- مراجعة النصوص العربية بواسطة محرر، ونسخة إنجليزية لاحقة بعد تثبيت العربية.
- حالات loading/empty/error/offline/recovery لكل رحلة رئيسية.
- تجنب لغة علاجية أو وعود صحية؛ إضافة توجيه للمساعدة المهنية عند الحاجة.

### 5. Release and operations — P0
- production keystore خارج المستودع، CI secrets، checksums.
- Android 10–15 device matrix، low-end performance، cold start، memory.
- dependency/SAST/SBOM، crash reporting privacy-preserving ومغلق افتراضيًا.
- internal → closed → staged rollout، migrations backward-compatible، rollback runbook.

## معايير الخروج
- `flutter analyze` بلا ملاحظات.
- اختبارات unit/widget/integration وbackup fuzzing ناجحة.
- round-trip backup 100%، tamper/wrong-passphrase fail closed.
- audit accessibility يدوي ونتيجة device matrix موثقة.
- توقيع production وتحقق checksum.
- لا claim للنشر العام قبل تحقق كل بوابات `release.md`.

## التنفيذ المتسلسل
1. **الآن:** Backup UX + file picker + preview/merge.
2. **بعدها:** DB fixtures، repository migration، delete/export controls.
3. **ثم:** encrypted-at-rest migration وlocal reminders.
4. **ثم:** content/audio، accessibility audit، performance.
5. **أخيرًا:** pairing/sync، release hardening، staged rollout.

## قرارات مؤجلة
- audio licensing/provider.
- هل pairing Wi-Fi Direct أم local network QR rendezvous.
- crash diagnostics opt-in أم build منفصل بلا diagnostics.
