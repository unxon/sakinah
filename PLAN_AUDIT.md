# Plan Audit — سَكينة

## النتيجة التنفيذية

الحالة الحالية هي **MVP واجهة Flutter قابل للبناء**، وليست بعد تطبيقًا كاملًا وفق خطة الإنتاج. البناء والـ analyzer والاختبارات الأساسية ناجحة، لكن معظم عناصر التخزين المحلي، الأمن، المزامنة، النسخ الاحتياطي، وإدارة المحتوى ما زالت تصميمًا أو ملفات أولية فقط.

التقييم التقريبي مقابل الخطة:

| المحور | الحالة الفعلية | التقييم |
|---|---|---:|
| Flutter/Android build | APK Release مبني وبياناته صحيحة | 100% |
| RTL/هوية/تنقل أساسي | موجود | 65% |
| Home/Library/Plans/Personal/Settings | شاشات موجودة، بعضها static | 45% |
| Reader/counter flow | غير منفذ فعليًا | 10% |
| Local persistence | State في الذاكرة فقط | 5% |
| SQLite/repositories | schema وrepository skeleton فقط | 10% |
| Content packages | JSON + model موجودان، غير موصولين بالواجهة | 30% |
| Security/Keystore/backup | غير منفذ | 0% |
| Backend relay | وثائق وmigration فقط، لا server code | 5% |
| Sync/CRDT/pairing | غير منفذ | 0% |
| Accessibility/states | توطين جزئي، لا audit أو Semantics شامل | 20% |
| Release readiness | APK قابل للتثبيت لكنه debug-signed | 45% |

## الانحرافات الحرجة

### 1. التطبيق لا يستخدم قاعدة بيانات محلية

الخطة تنص على SQLite وtransactions وmigrations وFTS. التنفيذ الحالي لا يستدعي `sqflite` ولا يفتح database. `lib/database_schema.sql` مجرد schema غير مستخدم، ومجلدا `lib/data/local` و`lib/data/repositories` فارغان.

الأثر: البيانات لا تستمر بعد إغلاق التطبيق، ولا توجد atomic writes أو migrations أو recovery.

المطلوب: تنفيذ `LocalDatabase`, migration runner, repositories، وربط AppState بها قبل اعتبار local-first مكتملًا.

### 2. العداد ليس مسارًا فعليًا

الخطة تتطلب counter events، UUID، timestamp، target cap، transaction وmerge idempotence. التنفيذ الحالي يعرض رقمًا من map داخل الذاكرة، ولا توجد شاشة Reader أصلًا ولا زر يضيف event.

الموجود في `domain_logic_test.dart` هو اختبار pure function فقط، وليس تكاملًا مع التطبيق.

المطلوب: إنشاء `ReaderScreen`, `CounterService`, `CounterEvent`, repository، واختبار relaunch وtarget cap وduplicate merge.

### 3. حزمة المحتوى غير موصولة بالواجهة

يوجد `Devotion` و`AssetDevotionRepository` و`core-ar.json`، لكن `SakeenaShell` يستخدم `demoCatalog` الثابت من `demo_catalog.dart`. أي تعديل في JSON لن يغيّر المكتبة الحالية.

كما أن `installPackage` و`removePackage` يرميان `UnsupportedError`، وmanifest لا يحتوي `manifestHash` أو `signature` فعلية، والترخيص placeholder.

المطلوب: composition root يحقن repository، importer يتحقق من schema/license/hash، وواجهة تعرض verified/package source.

### 4. Backend غير موجود فعليًا

`backend/src` فارغ. الموجود README و`SYNC_PROTOCOL.md` وPostgreSQL migration فقط. لا توجد endpoints أو authentication أو expiry أو chunk service أو tests.

المطلوب: خدمة relay مستقلة بعقد DTOs، اختبارات protocol، auth للمفاتيح العامة، chunk persistence، expiry، rate limiting وdeletion policy.

### 5. المزامنة والنسخ الاحتياطي غير منفذين

لا QR pairing، لا short code، لا scope preview، لا resume، لا conflict UX، لا CRDT adapter، لا encrypted backup export/restore، ولا Keystore-backed key management.

هذه ليست ميزات جزئية؛ هي غير موجودة في APK الحالي.

### 6. الشاشة وقارئ الدعاء غير متوافقين مع الخطة

الخطة تحدد Reader بخط كبير، مصدر، translation/audio bottom sheet، وعداد منفصل. التنفيذ الحالي يعرض بطاقات فقط. لا توجد `features/reader` implementation، ولا audio أو translation أو source flow.

### 7. الخطط والمفضلة والإعدادات شبه ثابتة

- الخطط بيانات ثابتة وليست قابلة للإنشاء أو التعديل أو pause.
- المفضلة تتغير في state فقط ولا تستمر.
- إعدادات الوضع الداكن والمصادر لا تغير state فعليًا في النسخة Flutter الحالية.
- النصوص الشخصية تُحفظ في قائمة ذاكرة فقط ولا تملك تعديلًا أو حذفًا آمنًا.

### 8. حالات UX المخططة غير مكتملة

غير موجودة فعليًا: first-run privacy، loading/error/empty للـ database، permission rationale/denied، offline information state، sync states، conflict notice، restore confirmation، fatal recovery.

يوجد empty state للنصوص الشخصية فقط، وbootstrap موجود كهيكل تصميمي قديم وليس `LocalBootstrap` حقيقيًا يفتح قاعدة البيانات ويشغل migrations.

### 9. Accessibility وreduced motion غير مكتملين

التوطين الرسمي أضيف، لكن لا يوجد Semantics labels شامل، ولا اختبار text scale 200%، ولا reduced-motion policy، ولا dynamic contrast audit، ولا تحقق TalkBack على الشاشات.

### 10. انحرافات release وconfiguration

- APK مبني بتوقيع debug وليس release keystore.
- `app_config.yaml` يذكر target SDK 35، بينما APK الفعلي target SDK 36.
- Android namespace هو `com.sakeena.sakeena` بينما applicationId هو `com.sakeena.devotions`; يفضل توحيدهما.
- `splash.svg` موجود كأصل، لكن Android launch resources ما زالت ملفات Flutter الافتراضية ولم تُربط بالهوية SVG فعليًا.
- يوجد فرق زمني بين source الحالي وAPK المبني: تم تعديل delegates بعد آخر build؛ يجب إعادة بناء APK بعد اعتماد النسخة النهائية.
- ملفات Android المنشأة من Flutter تحتوي تعليقات وقوالب افتراضية؛ يلزم تنظيفها قبل release حسب شرط codebase النظيف.

## ما هو صحيح ومكتمل نسبيًا

- Flutter project وAndroid project موجودان.
- `flutter analyze` يمر بلا مشاكل.
- `flutter test` يمر بثلاثة اختبارات.
- APK Release تم بناؤه بنجاح.
- اسم التطبيق وPackage ID والـ label العربي صحيحة.
- الاتجاه واللغة العربية مهيآن.
- التصميم العام والهوية والأيقونة موجودة.
- domain entity وrepository contract وحزمة JSON بدأت فصل المحتوى عن الواجهة.
- backend منفصل في المسار، ولا يوجد HTTP أو PostgreSQL import داخل Flutter.

## ترتيب الإصلاح قبل ادعاء اكتمال التطبيق

### P0 — ضروري قبل اعتماد MVP حقيقي

1. ربط `AssetDevotionRepository` بالواجهة بدل `demoCatalog`.
2. بناء SQLite database وrepositories وpersistence.
3. تنفيذ Reader + CounterEvent + CounterService.
4. جعل plans/favorites/personal/settings persistent.
5. إضافة privacy first-run وloading/error/recovery states.
6. إعادة بناء APK بعد آخر تغييرات source.

### P1 — ضروري قبل نسخة Beta

1. Keystore وحقول شخصية مشفرة.
2. Backup export/restore مع checksum وpassphrase.
3. مصادر/حزم signed مع license validation.
4. Accessibility audit وreduced motion وfont scale.
5. حذف static demo catalog ونقل كل feature إلى مجلده.

### P2 — بعد استقرار Local Core

1. QR pairing وscope preview.
2. encrypted chunk transfer وresume.
3. CRDT/event merge والتعارضات.
4. Backend relay فعلي واختبارات contract.
5. notifications/audio/import packages.

## حكم النشر

APK الحالي مناسب **للعرض والتجربة التقنية**، وليس مناسبًا بعد لوصفه كتطبيق إنتاج كامل أو لتخزين بيانات المستخدم المهمة؛ لأن state الأساسي يضيع بعد الإغلاق، والتوقيع Debug، وميزات الخصوصية/النسخ/المزامنة غير منفذة.

الخطوة الصحيحة التالية ليست إضافة شاشات تجميلية، بل تنفيذ P0 بالترتيب ثم إعادة التدقيق.
