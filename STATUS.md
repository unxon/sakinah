# حالة التنفيذ — سكون P0 Data Trust v7

- **المرحلة:** P0 data trust / privacy controls
- **T-008:** migration fixture v1→v2، تشفير legacy rows، rollback عند فشل التشفير، وفحص فقدان المفتاح مع شاشة استرداد واضحة مكتملة. يبقى device upgrade smoke.
- **T-009:** encrypted backup export، حدود 25MB/10,000 سجل، delete-all transactional، soft-delete، restore، purge، وتنظيف SharedPreferences مكتملة. يبقى direct export UX مستقل واختبار جهاز.
- **التشفير:** إذا اختفى مفتاح البيانات مع وجود صفوف مشفرة، لا ينشئ التطبيق مفتاحًا جديدًا بصمت؛ يعرض KeyRecoveryApp ويطلب الاستعادة من backup.
- **التحقق:** `dart format lib test` ناجح، `flutter analyze` بلا أخطاء، `flutter test` — 13 اختبارًا ناجحًا، `flutter build apk --release` ناجح.
- **APK:** `build/app/outputs/flutter-apk/app-release.apk`، الحجم 52.0MB.
- **SHA-256:** `1e2fba64e069c1db987cf6c24ae91d3f93f2589b244bf6d909deb8310309b068`.
- **بوابات P0 المتبقية:** اختبار Android فعلي/ترقية، rollback snapshot قابل للاستعادة بعد merge ناجح، direct export UX، accessibility audit، CI/SAST/SBOM، وproduction signing.
- **قرار الإصدار:** NO-GO للنشر العام حتى إغلاق البوابات المتبقية.
