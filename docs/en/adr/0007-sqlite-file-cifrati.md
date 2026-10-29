# ADR-0007 — SQLite (GRDB), per-row encrypted files, crypto-shredding

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 8, 9, 17.7

## Context
We need a reliable local store with migrations and observation, encryption of the contents, and a truly permanent deletion even when residual copies (backups) exist.

## Decision
- SQLite through GRDB as the single store for metadata (WAL, `PRAGMA secure_delete = ON`).
- Files of each row in `Items/<itemId>/`, encrypted with AES-GCM 256 (CryptoKit) with one key per row, stored in `item_key` encrypted by the master key in the Keychain.
- "Delete everything" = deletion of the key + files + text data and indexes. Without the key, residual copies are unreadable.
- IAGO folder excluded from Time Machine by default.

## Consequences
- Audio playback with decryption in memory or in `tmp/` (cleaned at the end of listening and at startup).
- Losing the master key = losing the data: in phase 2, "Export encrypted backup".
- Recordings in progress in `tmp/sessions/` are not encrypted until finalization.
