CREATE TABLE devices (
  id UUID PRIMARY KEY,
  public_key TEXT NOT NULL,
  label TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);
CREATE TABLE pair_sessions (
  id UUID PRIMARY KEY,
  initiator_id UUID NOT NULL REFERENCES devices(id),
  peer_id UUID REFERENCES devices(id),
  scope_hash TEXT NOT NULL,
  status TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE sync_chunks (
  session_id UUID NOT NULL REFERENCES pair_sessions(id) ON DELETE CASCADE,
  chunk_index INTEGER NOT NULL,
  chunk_hash TEXT NOT NULL,
  ciphertext BYTEA NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY(session_id, chunk_index)
);
