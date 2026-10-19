# Migration status

## الوضع الحالي

نقطة التشغيل صغيرة في `lib/main.dart`. تم تنفيذ P0 داخل `lib/app/sakeena_app.dart` مع `LocalStore` فعلي، bootstrap/loading، قارئ دعاء، عداد بحد مستهدف، حفظ المفضلة والنصوص، وربط الواجهة بـ `AssetDevotionRepository` وملف JSON المحلي. تمت ترقية LocalStore إلى migration v3 مع معرّفات النصوص الشخصية، التعديل، الحذف المؤكد، إدارة الخطط، وإعدادات الوضع الداكن وحجم النص والمصادر وتقليل الحركة، مع اختبارات CRUD.

## الترحيل التالي

1. نقل `AppState` والشاشات إلى مجلدات features بعد استقرار السلوك.
2. توسيع LocalStore إلى schema الكامل مع migrations وFTS.
3. إضافة plans/favorites/settings persistence كاملة.
4. إضافة backup مشفر وKeystore.
5. إبقاء backend خارج Flutter وإضافة client adapter فقط خلف interface.
6. تنفيذ pairing وsync بعد اعتماد local core.

كل خطوة مستقلة وقابلة للمراجعة؛ لا يتم تنفيذ big-bang rewrite.
