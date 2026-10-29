# ADR-0028 — Master key in the Keychain and per-item keys

- Status: accepted
- Date: 2026-10-12
- Spec references: sec. 9.2, 9.3, 16.3

## Context
The spec calls for a master key in the Keychain and a per-item key encrypted with the master key, so that deleting an item's key makes it unreadable (crypto-shredding). With the free Personal Team, the "data protection" Keychain, needed for shared access groups, requires entitlements that must be verified: it will only be needed in phase 3 for `iago-mcp`.

## Decision
- **Master key**: random AES-256, created at first launch, saved as a generic password in the login Keychain (service `com.giovannilombi.iago`, account `master-key`), **not syncable** with iCloud. macOS lets only the app that created it (same signature) read it without prompts.
- **Per-item key**: random AES-256, saved in `item_key.wrapped_key` sealed with AES-GCM by the master key, with the item ID as authenticated data (a key cannot be moved to another item).
- **Permanent deletion**: first the `item_key` row is deleted, then the files, then the texts in the DB. Leftover copies of the files (backups) remain unreadable.
- The Keychain sits behind the `MasterKeyStore` protocol: tests use an in-memory key.

## Consequences
- Changing the signature or bundle ID makes the master key inaccessible without the user's confirmation: consistent with the rule of not changing them (CLAUDE.md).
- Losing the master key (Keychain deleted) makes the archive unreadable: the phase 2 "Export encrypted backup" will need to include a way to recover it.
- Phase 3: verify the move to the "data protection" Keychain with an access group shared with `iago-mcp`, with key migration.
