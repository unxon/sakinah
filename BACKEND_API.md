# Backend اختياري — Sَكينة Sync Relay

## المبدأ
الـ backend ليس مطلوبًا لتشغيل التطبيق، ولا يرى نصوص الأدعية الشخصية أو المذكرات أو سجل القراءة. يستخدم فقط عندما يطلب المستخدم مزامنة جهازين موثوقين.

## خدمات API

| المسار | الوظيفة | البيانات |
|---|---|---|
| `POST /v1/pair/sessions` | بدء pairing | public key، device label، expiry |
| `POST /v1/pair/sessions/:id/approve` | موافقة الجهاز الآخر | fingerprint، scope hash |
| `POST /v1/sync/sessions/:id/chunks` | رفع قطعة مشفرة | ciphertext، chunk hash، index |
| `GET /v1/sync/sessions/:id/chunks` | جلب القطع | ciphertext فقط بعد auth |
| `POST /v1/sync/sessions/:id/complete` | إغلاق الجلسة | manifest hash، counts |
| `DELETE /v1/devices/:id` | إلغاء جهاز | device id، signed request |

## جداول PostgreSQL

`devices(id, public_key, label, created_at, last_seen_at, revoked_at)`

`pair_sessions(id, initiator_id, peer_id, expires_at, scope_hash, status)`

`sync_chunks(session_id, index, hash, ciphertext, size, created_at, primary key(session_id,index))`

`audit_events(id, session_id, event_type, created_at)` دون نصوص أو محتوى شخصي.

## الحماية

TLS، public-key authentication، expiry قصير، replay nonce، حد حجم للقطع، rate limit، deletion بعد مدة احتفاظ قصيرة، وعدم وجود endpoint بحث أو feed أو analytics.

## حالات العميل

`idle → pairing → preview → awaitingApproval → syncing → interrupted → resumable → completed`، وأي فشل في التحقق ينتقل إلى `fatalRecoveryRequired` دون تعديل البيانات المحلية.
