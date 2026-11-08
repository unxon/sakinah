# Tasks

مرجع التوسع: `PRODUCT_EXPANSION_PLAN.md`. كل مهمة تتطلب كودًا، اختبارًا، تحديث توثيق، ودليلًا في `status.md`.

## Foundation and trust

- DONE T-001 UI foundation and RTL (FR-001..003, UX-001).
- DONE T-002 SQLite schema v1 and migration boundary (NFR-001).
- DONE T-003 SecureVault wrapper (SEC-001).
- DONE T-004 LocalRepository + SQLite summary hydration/export/import; runtime reads latest journal/mood/session summary from SQLite.
- PARTIAL T-005 BackupCodec PBKDF2-HMAC-SHA256 + AES-256-GCM with round-trip/tamper tests; Backup UX implementation in progress.
- IN PROGRESS T-006 Backup/Restore UX: file picker, passphrase, preview, merge confirmation, cancel/error/recovery states.
- DONE T-007 Repository reads and transactional in-memory/file SQLite fixtures; 2 database integration tests.
- PARTIAL T-008 AES-GCM encrypted-at-rest writes, schema v2 columns, legacy migration fixture, rollback test, and key-loss recovery gate complete; remaining: device upgrade smoke.
- PARTIAL T-009 Export via encrypted backup, delete-all, soft-delete, restore, and purge complete; remaining: direct export UX and device validation.

## Product depth

- TODO T-010 Natural sound player with licensed asset manifest, offline cache, disposal and audio focus.
- TODO T-011 Guided content catalog: sleep, anxiety, focus, morning, evening, with editorial review.
- TODO T-012 Local reminders with permission-denied fallback and quiet hours.
- TODO T-013 Accessibility audit: semantics, large text, contrast, reduced motion, RTL and touch targets.
- TODO T-014 Content safety review: non-clinical language, crisis/helpful-resource copy, localization glossary.

## Trusted devices

- TODO T-015 QR pairing and peer revocation with scope preview and expiry.
- TODO T-016 Resumable idempotent sync adapter with tombstones and deterministic conflict policy.
- TODO T-017 Sync recovery tests: interruption, duplicate delivery, revoked peer, schema mismatch.

## Quality and release

- TODO T-018 Device matrix Android 10–15, low-end performance, cold start and memory budget.
- TODO T-019 Dependency audit, SAST, SBOM, backup fuzzing and privacy log review.
- TODO T-020 Production signing, CI release artifacts, checksum verification and Play internal track.
- TODO T-021 Staged rollout, monitoring, rollback drill and incident runbook.

**Current executable task:** T-008 migration fixture + rollback/key-loss tests, then T-009 delete/export lifecycle.
