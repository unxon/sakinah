# سَكينة — خطة الإنتاج الشاملة

## 1. الرؤية

سَكينة تطبيق أدعية وأذكار عربي أولًا، هادئ وغير تنافسي، يعمل دون إنترنت ويحتفظ بالبيانات على جهاز المستخدم. كل ميزة أساسية متاحة قبل إنشاء أي حساب أو منح صلاحية، والمزامنة بين الأجهزة اختيارية ومحددة النطاق وتحتاج موافقة صريحة.

## 2. النظام المقترح

| الطبقة | المسؤولية | التقنية المقترحة |
|---|---|---|
| Presentation | الشاشات، RTL، animation، accessibility | Flutter + Material 3 custom theme |
| State | حالات idle/loading/ready/empty/error/syncing | ChangeNotifier في MVP، Riverpod عند التوسع |
| Domain | العداد، الخطط، المفضلة، الدمج، الصلاحيات | Pure Dart بدون Flutter أو شبكة |
| Data | معاملات SQLite، migrations، FTS، cache | sqflite + repository interfaces |
| Security | مفاتيح الجهاز، حقول حساسة، النسخ المشفر | Android Keystore + flutter_secure_storage |
| Sync adapter | pairing، scope preview، chunks، resume | P2P adapter اختياري؛ لا يعتمد عليه الـ core |
| Backend optional | relay للـ pairing/transfer فقط دون قراءة المحتوى | Stateless relay، PostgreSQL للـ device/session metadata |

## 3. Backend وقاعدة البيانات

### Local SQLite

الجداول الأساسية: `devotion_packages`, `devotion_items`, `sources`, `favorites`, `collections`, `plans`, `plan_entries`, `counter_sessions`, `counter_aggregates`, `personal_texts`, `audio_assets`, `reminder_links`, `sync_documents`, `backup_manifests`.

كل سجل قابل للمزامنة يملك UUID ثابتًا و`created_at`, `updated_at`, `source_device_id`, `version`, و`tombstone`. الكتابات تتم داخل transaction؛ أي تحديث للمحتوى مع عداده ينجح كاملًا أو لا يكتب شيئًا.

### Backend optional

الخادم لا يصبح مصدر الحقيقة. دوره المقترح هو relay مؤقت لجلسة pairing وقطع مشفرة لا يستطيع قراءتها. التخزين الدائم إن لزم يحوي device public keys، session expiry، chunk hashes، وaudit metadata غير الحساسة. لا نخزن نصوص المستخدم أو مذكراته أو سجل قراءته بصورتها الصريحة.

## 4. منطق وخوارزميات

### عداد الذكر

1. عند فتح العنصر يقرأ التطبيق `counter_aggregate` المحلي.
2. الضغط يضيف event محليًا بمعرّف UUID وtimestamp monotonic.
3. يمنع التطبيق الزيادة بعد `target_count` في الجلسة الحالية.
4. يحدّث aggregate داخل transaction.
5. عند المزامنة تُدمج أحداث العداد باتحاد UUIDs، لا بجمع aggregate فقط، لمنع double counting.

### تقدم خطة اليوم

`progress = completed_entries / max(1, due_entries)`، وتُحسب المنطقة الزمنية من إعداد الجهاز. لا توجد streaks أو ترتيب اجتماعي. إذا تغيرت الخطة، يبقى السجل السابق محفوظًا ولا يعاد تفسيره بصمت.

### البحث العربي

يُنشأ حقل FTS تطبيعي: إزالة التشكيل والتطويل، توحيد الهمزات، تحويل `ى/ي` و`ة/ه` وفق سياسة بحث ثابتة، مع حفظ النص الأصلي للعرض. النتائج تعرض مصدر الحزمة بوضوح وتفصل المحتوى الموثق عن النص الشخصي.

### المزامنة

1. Pairing عبر QR أو رمز قصير.
2. تبادل public keys والتحقق من fingerprint.
3. Scope preview يعرض الأنواع والأعداد قبل الإرسال.
4. تقسيم الملف إلى chunks مع hash لكل قطعة.
5. استئناف من آخر chunk مؤكد بعد الانقطاع.
6. دمج CRDT للبيانات القابلة للمزامنة.
7. عداد الذكر يدمج event IDs؛ النصوص المتعارضة تنشئ نسخة conflict ولا تحذف الأصل.
8. ملخص مكتمل مع عدد الإضافات والتعارضات والأخطاء.

### النسخة الاحتياطية

الملف يحتوي manifest وversion وKDF parameters وchecksum وأقسامًا مشفرة. الاستعادة تمر عبر تحقق الصيغة، الحجم، checksum، passphrase، وmigration قبل الكتابة. الملف التالف يفشل مغلقًا دون تعديل قاعدة البيانات الحالية.

## 5. Progressive Disclosure

- المستوى الأول: اليوم، الدعاء، زر القراءة/العداد.
- المستوى الثاني: المصدر، المفضلة، الخطة، الصوت.
- المستوى الثالث: التخصيص، التذكير، الاستيراد والنسخ.
- المستوى الرابع: pairing، scope، conflict resolution، diagnostics.

لا نعرض مصطلحات CRDT أو Keystore أو calculation policy للمستخدم العادي. تظهر التفاصيل التقنية فقط داخل إعدادات متقدمة أو شاشة تشخيص اختيارية.

## 6. التصميم والحركة

الهوية: Organic editorial، خلفية كريمية، Sage للطمأنينة، Terracotta للفعل، Gold للتفاصيل الهادئة. الحركة قصيرة وهادفة: fade/slide من 220–320ms، counter pulse عند النجاح، progress fill عند إكمال خطوة، bottom sheet للقراءة والإضافة. عند reduced-motion نلغي scale والـ parallax ونبقي انتقال opacity بسيطًا.

## 7. شاشة الإقلاع والتحميل

Splash ثابتة بالعلامة لمدة لا تتجاوز 900ms، ثم `LocalBootstrap`: فتح SQLite، تشغيل migrations، تحميل الإعدادات، وفحص recovery journal. تعرض عبارة «نجهّز مساحتك...» دون شبكة. عند فشل الاستعادة يظهر مسار آمن: «فتح آخر نسخة سليمة» أو «إدارة البيانات».

## 8. الشاشات والحالات

- Splash / bootstrap / migration recovery.
- Privacy first-run: محلي افتراضيًا، لا تتبع، مزامنة اختيارية.
- Home: خطة اليوم، المفضلة، الأحدث، empty state.
- Library: بحث، تصنيف، مصدر الحزمة، content loading/error/offline.
- Reader: نص كبير، source bottom sheet، translation/audio optional، counter action منفصل.
- Plans: إنشاء، تعديل، pause، empty، validation.
- Personal text: إضافة، تعديل، حذف آمن، label خاص.
- Pairing: QR، رمز بديل، trust fingerprint، scope preview، progress، pause، resume، conflict، summary.
- Backup: export success/failure، restore confirmation، wrong passphrase، corrupt file.
- Settings: theme، font scale حتى 200%، Arabic numerals، reduced motion، privacy، peer revoke.

## 9. الوصول والتوطين

RTL حقيقي، Semantics labels عربية، ترتيب TalkBack مطابق للقراءة، touch targets >= 48dp، تباين ديناميكي، دعم text scale 200%، وعدم الاعتماد على اللون وحده. كل رسالة فشل مرتبطة بحقلها أو الإجراء ولا تعتمد على toast فقط.

## 10. مراحل التنفيذ

### Phase 0 — foundation
Flutter shell، theme، splash، SQLite migrations، repositories، local error model.

### Phase 1 — MVP
Catalog، reader، counter، favorites، plans، personal text، settings، local backup، tests offline.

### Phase 2 — hardening
Keystore، signed packages، encrypted fields، audio/notifications، import validation، accessibility audit.

### Phase 3 — sync
QR pairing، trusted devices، encrypted chunks، resumable transfer، CRDT merge، conflict UX.

### Phase 4 — release
Performance، crash recovery، migration matrix، threat review، Android device matrix، APK/AAB release.
