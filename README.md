# سَكينة Flutter

تطبيق هاتف عربي RTL مبني على Flutter، Local-first، يعمل دون إنترنت في الوظائف الأساسية.

## البنية

- `lib/main.dart`: نقطة التشغيل فقط.
- `lib/app`: composition root وربط dependencies.
- `lib/domain`: entities وrepository contracts وقواعد الأعمال.
- `lib/data`: SQLite وAsset packages وrepository implementations.
- `lib/features`: شاشات مستقلة لكل feature.
- `assets/content/packages`: حزم أدعية JSON قابلة للإضافة دون تعديل Widgets.
- `backend`: relay اختياري منفصل للمزامنة المشفرة فقط.

## إضافة دعاء

أضف عنصرًا إلى حزمة JSON أو أنشئ package جديدة باستخدام القالب في `assets/content/packages/README.md`. لا تضع الدعاء داخل Dart أو Widget. بعد اعتماد الترخيص والـ manifest hash، يمرر المحتوى إلى importer المحلي.

## التشغيل والبناء

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

البيئة الحالية لا تحتوي Flutter SDK أو Android SDK، لذلك المصدر والتهيئة جاهزان، لكن لا يوجد APK مُنشأ فعليًا بعد.
