# Sync protocol boundary

Frontend يرسل فقط DTOs موقعة ومشفرة:

- `PairRequest(deviceId, publicKey, expiresAt)`
- `ScopePreview(entityTypes, counts, payloadBytes)`
- `Chunk(index, total, hash, ciphertext)`
- `SyncReceipt(acceptedIndexes, remoteVectorClock)`

Backend relay يعيد DTOs ولا يعيد domain entities. عملية الدمج والعداد وفض التعارض تبقى داخل التطبيق المحلي. أي تغيير في protocol يرفع `schemaVersion` ويضيف migration متوافقًا.

لا يوجد endpoint يعيد محتوى شخصيًا مفكوكًا، ولا endpoint بحث، ولا analytics.
