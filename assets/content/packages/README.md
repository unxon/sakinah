# Content package format

لإضافة حزمة جديدة، انسخ `core-ar.json` إلى ملف جديد، غيّر `packageId` و`version` وأضف `items`، ثم سجّل الملف في `pubspec.yaml` أو مرره إلى importer المحلي.

لا تضع Widget أو Dart logic داخل الحزمة. لا تضع نصوصًا شخصية هنا. قبل release يجب استبدال `REPLACE_WITH_APPROVED_LICENSE` برخصة ومصدر معتمدين وإضافة manifest hash/signature.
