# سكون — Serenity & Reflection

تطبيق Android-first عربي مبني بـ Flutter، يعمل محليًا ويحافظ على خصوصية المستخدم. تم تحويل الشريحة التفاعلية الأولى إلى تطبيق هاتف حقيقي قابل للبناء.

## ما يعمل الآن
- واجهة RTL عربية بألوان هادئة ودعم Material 3.
- الصفحة الرئيسية والتنقل بين الرئيسية والجلسة والمذكرات والتقدّم.
- جلسة تأمل 5 دقائق مع بدء/إيقاف/إعادة وتسجيل الجلسات المكتملة.
- تمارين تنفّس ونصوص إرشادية ضمن مسار MVP.
- يوميات خاصة مع اختيار الحالة وحفظ محلي دائم عبر `shared_preferences`.
- تقدّم بلا منافسة أو سلاسل.
- شاشة خصوصية توضّح عدم وجود حساب أو إعلانات أو تحليلات أو تتبع.

## التشغيل والبناء

```bash
export PATH="/home/ubuntu/sdk/flutter/bin:$PATH"
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

الحد الأدنى الحالي يتطلب Flutter stable وAndroid SDK. لتثبيت نسخة التجربة على جهاز Android:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

> نسخة release الحالية موقعة بمفتاح debug الخاص بقالب Flutter لأغراض التجربة فقط، وليست جاهزة للنشر في Google Play. يجب توفير مفتاح توقيع إنتاجي قبل الإطلاق.

## الخطط التالية

وفق المواصفات الموجودة في `docs/`: نقل التخزين القابل للبحث إلى SQLite، إضافة Android Keystore للبيانات الحساسة، backup/restore مشفر، استيراد حزم موقعة، ثم pairing ومزامنة P2P اختيارية بين أجهزة موثوقة.
