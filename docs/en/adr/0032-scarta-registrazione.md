# ADR-0032 — "Discard" during recording and "Temporarily discarded"

- Status: accepted (user request, 2026-10-12)
- Date: 2026-10-12
- Spec references: FR-17, FR-20; ADR-0030

## Context
FR-17 always saves the recording on Stop. The user wants to be able to throw away a recording started by mistake or not useful without going through the 30-day Trash, but with a margin to change their mind.

## Decision
- During a recording, in the window bar and in the menu bar menu, there is **"Discard"** (with confirmation).
- The recording stops, is saved and encrypted as always (no loss in case of a crash), then goes to the Trash in a separate section, **"Temporarily discarded"** (`item.trash_reason = 'discarded'`), without the post-recording panel.
- After **1 hour** it is deleted permanently (crypto-shredding). Until then it can be restored or deleted immediately. The check for Trash expirations goes from once a day to every 5 minutes.

## Consequences
- Deviation from FR-17 for discarded recordings only.
- Migration `v2-discarded` (column `item.trash_reason`).
- If IAGO stays closed for more than an hour, the discarded recording is deleted at the next launch.
