# ADR-0029 — Phase 0 recordings imported into the encrypted archive

- Status: accepted (choice confirmed by the user, 2026-10-12)
- Date: 2026-10-12
- Spec references: sec. 9.1; ADR-0007, ADR-0016, ADR-0024

## Context
In phase 0, finalized recordings were saved unencrypted in `Recordings/<itemId>/` (`mic.m4a`, `system.m4a`, `mix.m4a`, `session.json`), pending the phase 1 encryption. Leaving them unencrypted contradicts sec. 9; deleting them would lose the user's real calls.

## Decision
- At launch, each folder in `Recordings/` goes through the same path as new recordings (`RecordingArchiver`): an `Unclassified · …` item with the start date, tracks encrypted in `Items/<itemId>/`, bookmarks imported into the `marker` table (with the time already moved back by 5 s, ADR-0024), pauses and device changes in `item.capture_meta`.
- Each unencrypted file is deleted only after its encrypted copy is written; the folder is deleted at the end; `Recordings/` is removed when empty.
- The same path archives at launch the recordings left in `tmp/finalized/` (crash between finalization and encryption): it is idempotent.

## Consequences
- After the first phase 1 launch, no unencrypted audio remains outside `tmp/sessions/` (recordings in progress).
- The item ID is the session ID: a phase 0 bookmark or reference remains valid.
- Verified on 2026-10-12: 23 recordings imported, no unencrypted file in `Items/`, `Recordings/` removed.
