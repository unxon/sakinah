# Sakeena Sync Relay

Backend منفصل اختياري. لا يدخل في تشغيل التطبيق الأساسي.

## مسؤولياته

Pairing مؤقت، public-key authentication، تخزين chunks مشفرة، resume، expiry، revoke، وrate limiting.

## غير مسؤول عنه

لا يدير الأدعية، لا يحسب العداد، لا يقرر الخطط، لا يفك تشفير النصوص الشخصية، ولا يقدم حسابات اجتماعية أو analytics.

## تنفيذ مقترح

Phase 1: Dart Frog أو Node/Fastify API صغير مع PostgreSQL.
Phase 2: object storage مؤقت للقطع مع lifecycle deletion.
Phase 3: contract tests من ملف `SYNC_PROTOCOL.md`.
