# مراجعة شاملة — سكون — 2026-10-15

## 1. نطاق ومنهج المراجعة

راجعت الكود الفعلي في `lib/` و`test/`، مخطط SQLite، خدمات التشفير والنسخ الاحتياطي، Android build، ملفات الخطة والمهام والتصميم والواجهة/backend. شغّلت `dart format lib test` و`flutter analyze` و`flutter test` و`flutter build apk --release`.

النتائج المثبتة في هذه الجلسة: التحليل بلا أخطاء، 9 اختبارات ناجحة، وAPK release ناجح. هذه ليست مراجعة penetration test أو device certification؛ ما لم يُشغّل فعليًا مصنف كـ غير متحقق.

## 2. الحكم التنفيذي

**الحالة:** Production foundation متقدم، لكنه ليس Release Candidate ولا جاهزًا للنشر العام.

**نقاط القوة:** local-first واضح، لا backend مركزي ولا analytics، RTL وتجربة عربية متماسكة، backup مشفّر، تشفير عند السكون، repository وSQLite، وفحوصات قابلة لإعادة التشغيل.

**إصلاح أثناء المراجعة:** اكتُشف أن `mood_checkins.mood` كان يبقى صريحًا رغم تشفير `note`. تم تعديل schema/ترحيل/قراءة/استعادة هذا الحقل وإضافة assertion له، ثم نجحت الفحوصات التسع.

**أكبر المخاطر الحالية:** واجهة Flutter monolithic، عدم وجود device/integration testing لمسارات النظام، migration من v1 غير مثبت fixture، فقدان مفتاح Keystore بلا recovery UX، backup غير محدود الحجم وبدون rollback قبل الدمج، عدم اكتمال delete/export controls، وتعارض/تكرار وثائق Flutter مع بقايا web MVP.

**قرار الإطلاق:** NO-GO حاليًا. يمكن مواصلة التطوير داخليًا، لكن لا يجوز وصف النسخة بأنها production-ready أو Play-ready.

## 3. Frontend وUI/UX

### ما يعمل

- تجربة عربية RTL، onboarding، privacy note، home، sessions، breathing، journal، mood، progress، settings، وBackup/Restore.
- dark mode وreduced motion وlaunch/splash وMaterial 3 tokens موجودة.
- Backup UX يطلب passphrase، يتيح file picker، يعرض preview قبل الدمج، ويعطي حالات نجاح/إلغاء/خطأ.
- النص العام هادئ وغير ضاغط ولا يعتمد streaks.

### الملاحظات

**P1 — بنية الصيانة:** معظم الواجهة في `lib/main.dart` بحوالي 1300 سطر، مع `LocalStore` وscreens وdialogs وdesign tokens في ملف واحد. هذا يرفع احتمال regression ويصعّب اختبار كل feature. المطلوب فصل `features/`, `core/design_system/`, `state/`, `routes/` و`l10n/`.

**P1 — حالة التطبيق:** `ChangeNotifier` واحد يمسك settings والجلسات واليوميات والتنقل الضمني. لا توجد حدود واضحة بين UI state وdomain state وpersistence state، ولا error state موحد. المطلوب controllers/use-cases صغيرة مع state models صريحة.

**P1 — اختبار UI غير كافٍ:** 3 اختبارات widget فقط؛ لا يوجد اختبار onboarding/privacy، dark mode، reduced motion، validation، BackupPage، preview/merge/cancel، file-picker failure، large text، أو screen reader semantics.

**P1 — صلاحية الوصول:** توجد نية تصميمية جيدة، لكن لا يوجد دليل آلي/يدوي على semantics، contrast، text scaling، keyboard focus، touch targets، أو Android screen reader. يجب عدم اعتبار UX-001 مكتملًا قبل audit.

**P2 — المحتوى:** النصوص جيدة كبداية، لكن لا توجد طبقة localization ولا glossary ولا مراجعة تحريرية/سلامة محتوى موثقة. توجد حاجة لنص واضح يفرق بين wellness tool والعلاج الطبي، مع مسار مساعدة عند الأزمات دون ادعاءات صحية.

**P2 — الحماية أثناء الاستخدام:** لا يوجد app lock أو إخفاء محتوى عند background/app switcher. هذا ليس مطلوبًا لكل مستخدم، لكنه قرار خصوصية يجب أن يكون setting اختياريًا قبل الإطلاق.

## 4. Database وdata model

### ما يعمل

- SQLite schema v2، indices أساسية، UTC timestamps، forward migration boundary.
- Repository يعيد آخر يومية ومشاعر وعدد الجلسات من SQLite.
- اختبارات persistence وexport/import وencrypted fields موجودة.
- body/mood/note تُشفّر AES-GCM عند توفر مفتاح البيانات، والنص الصريح لا يبقى في الأعمدة الأساسية.

### المخاطر

**P0 — فقدان المفتاح:** عند حذف/إعادة ضبط Android Keystore أو تثبيت التطبيق من جديد، قد يصبح المحتوى المشفّر غير قابل للفك. لا يوجد recovery state أو key-loss detection أو شرح للمستخدم أو export preflight مضمون قبل ذلك. يجب إضافة key identifier، health check، حالة `DATA_UNRECOVERABLE`، ومنع توليد مفتاح جديد بصمت فوق بيانات مشفّرة قديمة.

**P1 — migration غير مثبت:** كود v1→v2 موجود، لكنه لم يُختبر على ملف v1 حقيقي يحتوي بيانات legacy. لا يوجد fixture يثبت schema القديم، نجاح migration، rollback عند فشل seal، أو سلوك interrupted upgrade.

**P1 — rollback/backup:** خطة المنتج تطلب preflight backup وrollback، لكن `open()` وmigration لا ينفذان preflight backup، و`importSnapshot` يدمج مباشرة دون إنشاء rollback snapshot تلقائي.

**P1 — soft delete غير مكتمل:** يوجد `deleted_at` في schema، لكن لا توجد عمليات delete/restore، والاستعلامات والتصدير لا تستبعد السجلات المحذوفة ولا تعالج lifecycle. هذا يخالف T-009 وdata lifecycle.

**P1 — نموذج خام:** repository يعيد `Map<String,dynamic>` بدل entities typed مع validation وnullability واضحة. خطأ schema أو field type قد يظهر runtime فقط.

**P2 — idempotency:** IDs مبنية على milliseconds وبعضها يضيف counter؛ collision أو duplicate delivery ليست مغطاة رسميًا. المطلوب UUID/ULID أو generator موحد، وunique conflict policy موثقة لكل entity.

**P2 — metadata:** timestamps وبعض metadata تبقى صريحة وهذا مقبول غالبًا، لكن يجب توثيق threat model: ما الذي يحميه field encryption وما الذي لا يحميه.

## 5. Backend وlogic

لا يوجد backend مركزي فعليًا، وهذا متسق مع local-first. لكن `backend.md` يصف peer auth وP2P وsync كأنها حدود متاحة بينما لا يوجد adapter أو protocol implementation في الكود. يجب وسمها صراحة **planned/not implemented** حتى لا يوحي التوثيق بوجود backend.

الـ business logic ما زال قريبًا من widgets. مثال واضح: `completeSession()` يسجل `durationSeconds: 300` ثابتة، لا مدة الجلسة الفعلية. هذا يفسد progress data عند تغيير مدة الجلسة أو الإيقاف المبكر. يجب تمرير session result typed يحتوي actual elapsed duration وcompletion status.

لا يوجد use-case boundary موحد للتالي: حفظ اليومية، إكمال الجلسة، الدمج من backup، حذف البيانات، migration، وsync المستقبلي. المطلوب application services تمنع widget من معرفة تفاصيل DB/Preferences.

## 6. Algorithms وcrypto

### الإيجابيات

- Backup يستخدم PBKDF2-HMAC-SHA256 وAES-256-GCM وsalt/nonce/MAC عشوائية.
- Sensitive fields تستخدم مفتاحًا منفصلًا في Keystore وAES-GCM.
- wrong passphrase/tampering يفشلان بدل قبول بيانات صامتة.

### التحسينات المطلوبة

**P0 — key lifecycle:** يجب تصميم rotation، invalidation، lost-key، backup key مقابل data key، وإعادة تثبيت التطبيق. لا يكفي إنشاء key جديد عند غياب القديم.

**P1 — backup resource limits:** `previewRestore` يقرأ الملف كاملًا إلى الذاكرة مع `withData: true` بلا حد حجم أو schema depth/row count. أضف حدًا مثل 10–25MB، فحصًا قبل فك التشفير، وحدودًا للصفوف والنصوص لمنع memory/CPU abuse.

**P1 — merge semantics:** reflection يستبدل، sessions وmoods تتجاهل duplicates، لكن السياسة غير ظاهرة للمستخدم وغير موثقة كـ conflict policy. يجب إظهار عدد added/replaced/skipped وتسجيل import report.

**P1 — KDF tuning:** 120,000 iteration قرار غير مقاس على أجهزة Android منخفضة. يجب benchmark على Android 10 low-end وتوثيق زمن مستهدف، مع format version يسمح برفع الكلفة مستقبلًا.

**P2 — passphrase UX:** لا يوجد confirmation field أو strength meter أو تطبيع Unicode موثق. أضف confirmation ونسخة format metadata/AAD موثقة.

**P2 — crypto API hygiene:** اجعل key bytes immutable داخليًا، ولا تسمح بإنشاء codec بمفتاح بطول خاطئ دون رسالة واضحة. أضف fuzz/property tests للـ envelope وJSON fields.

## 7. جودة الكود والاختبارات

### مثبت

- `flutter analyze`: بلا أخطاء.
- `flutter test`: 9 اختبارات ناجحة.
- release APK يبنى بنجاح.
- وجود اختبارات backup وdatabase وwidget أفضل من scaffold فقط.

### الفجوات

- لا توجد integration tests حقيقية للتطبيق على Android.
- لا يوجد test migration v1→v2.
- لا يوجد test rollback/failure injection.
- لا يوجد test file picker أو Android permissions.
- لا يوجد performance/memory benchmark.
- لا يوجد dependency vulnerability/SAST/SBOM evidence فعلي؛ `sast-report.md` ما زال يصف checks غير منفذة.
- لا توجد CI pipeline أو reproducible artifact workflow.
- لا يوجد lint مخصص للـ architecture أو منع imports من widgets إلى DB.

## 8. Linking والاتساق

**P1 — duplicate documentation:** يوجد `STATUS.md` و`status.md`، إضافة إلى وثائق root و`docs/` القديمة. هذا يخلق أكثر من source of truth.

**P1 — stale task pointer:** `tasks.md` ما زال يقول إن current executable task هو إنهاء T-006 ثم T-007، رغم أن الحالة الفعلية وصلت إلى T-008/review. يجب تحديثه بعد كل milestone.

**P1 — legacy web MVP:** المستودع يحتوي `index.html`, `app.js`, `styles.css`, `tests/app.test.js` بجانب Flutter. لا توجد وثيقة تحدد هل web MVP جزء من المنتج أم legacy artifact. هذا يؤثر على CI، release، وملكية source of truth.

**P1 — docs drift:** `frontend.md` يذكر routes مستقبلية مثل pairing، و`backend.md` يذكر peer auth، دون تنفيذ. يجب استخدام labels `implemented / partial / planned` في كل وثيقة.

**P2 — identifiers:** requirement IDs في ملفات الخطة ليست مربوطة باختبارات فعلية test IDs. أضف traceability table FR/UX/SEC → code → test → evidence.

## 9. مقارنة مباشرة مع الخطة

| مسار الخطة | الحالة الواقعية | النقص الرئيسي |
|---|---|---|
| SQLite/repository | جزئي متقدم | typed entities، delete lifecycle، migration fixture |
| Backup/Restore | جزئي متقدم | limits، rollback، device smoke، import report |
| Encrypted at rest | جزئي متقدم | key-loss recovery، v1 fixture، rollback، rotation |
| UI/UX | MVP متقدم | فصل architecture، accessibility audit، UI integration coverage |
| Content/audio | غير منفذ | catalog، licensing، offline cache، audio focus |
| Reminders | غير منفذ | permission flow، quiet hours، fallback |
| P2P pairing | غير منفذ | threat model implementation، QR scope/revocation |
| Sync | غير منفذ | protocol، tombstones، conflict/recovery tests |
| Quality/security | جزئي | SAST/SBOM/dependency audit/CI/device matrix |
| Release | غير جاهز | production signing، Play internal، rollback drill |

## 10. ترتيب الأولويات المقترح

### P0 قبل أي claim production

1. key-loss detection وrecovery policy.
2. v1→v2 migration fixture وfailure/rollback tests.
3. backup size/row limits وpreflight rollback.
4. حذف/تصدير البيانات وsoft-delete lifecycle.
5. إزالة ازدواجية الوثائق وتحديد Flutter كمصدر الإصدار.
6. integration smoke على جهاز Android.

### P1 بعد تثبيت الثقة

1. فصل main.dart إلى modules وtyped domain models.
2. accessibility audit وlarge text/screen reader.
3. actual session duration/progress correctness.
4. content catalog/audio/reminders.
5. CI، dependency audit، SBOM، performance budget.

### P2 قبل التوسع متعدد الأجهزة

1. pairing/revocation/expiry.
2. resumable sync وconflict policy.
3. device matrix Android 10–15.
4. staged rollout وprivacy-preserving diagnostics.

## 11. الخلاصة

المشروع تجاوز مرحلة prototype وأصبح لديه أساس حقيقي قابل للتطوير، لكن قوته الحالية في **local foundation والتشفير الأساسي** لا في اكتمال المنتج أو جاهزية الإصدار. أكبر تحسين نوعي ليس إضافة شاشة جديدة؛ بل تقوية lifecycle للبيانات، فصل طبقات الكود، إغلاق فجوات الاختبار، وتوحيد الوثائق. بعد إغلاق P0 يمكن الانتقال بثقة إلى audio/reminders وaccessibility، وبعدها فقط pairing/sync.
