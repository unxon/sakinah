PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS devotion_items (
  id TEXT PRIMARY KEY,
  package_id TEXT NOT NULL,
  title TEXT NOT NULL,
  normalized_title TEXT NOT NULL,
  body TEXT NOT NULL,
  tag TEXT NOT NULL,
  source_id TEXT,
  target_count INTEGER NOT NULL DEFAULT 1,
  is_verified INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  tombstone INTEGER NOT NULL DEFAULT 0
);
CREATE VIRTUAL TABLE IF NOT EXISTS devotion_search USING fts5(item_id UNINDEXED, title, body, content='devotion_items', content_rowid='rowid');
CREATE TABLE IF NOT EXISTS favorites (item_id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, tombstone INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS plans (id TEXT PRIMARY KEY, name TEXT NOT NULL, timezone TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS plan_entries (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, item_id TEXT NOT NULL, due_rule TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, FOREIGN KEY(plan_id) REFERENCES plans(id));
CREATE TABLE IF NOT EXISTS counter_events (id TEXT PRIMARY KEY, item_id TEXT NOT NULL, session_id TEXT NOT NULL, occurred_at INTEGER NOT NULL, source_device_id TEXT NOT NULL, tombstone INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS personal_texts (id TEXT PRIMARY KEY, title TEXT NOT NULL, body_ciphertext BLOB NOT NULL, nonce BLOB NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, tombstone INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS sync_documents (id TEXT PRIMARY KEY, schema_version INTEGER NOT NULL, payload_ciphertext BLOB NOT NULL, vector_clock TEXT NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS backup_manifests (id TEXT PRIMARY KEY, format_version INTEGER NOT NULL, kdf_params TEXT NOT NULL, checksum TEXT NOT NULL, exported_at INTEGER NOT NULL);
