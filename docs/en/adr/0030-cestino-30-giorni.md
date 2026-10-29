# ADR-0030 — Trash with automatic deletion after 30 days

- Status: accepted (user request, 2026-10-12)
- Date: 2026-10-12
- Spec references: FR-60, FR-61, FR-62, sec. 9.3, 17.D

## Context
FR-62 calls for immediate permanent deletion, without a trash, and open decision D left the choice to be made. The user wants to be able to recover from mistakes.

## Decision
- When deleting an **item** ("Delete everything") or a **single asset**, IAGO always asks: **Move to Trash** / **Delete permanently** / Cancel.
- In the Trash (`item.trashed_at`, `asset.trashed_at`) the files stay encrypted with their key; the item disappears from lists, search, and exports, and keeps its notes and bookmarks.
- "Trash" view: Restore, Delete permanently, Empty Trash, days remaining.
- **30 days** after the move, the deletion becomes permanent (crypto-shredding as in sec. 9.3). Checked at launch and once a day.
- Exceptions:
  - "Transcribe and delete the audio" deletes the audio permanently: that is the explicit choice of the action (FR-54);
  - individual notes are deleted with confirmation, without the Trash.

## Consequences
- Deviation from FR-62 and closure of open decision D.
- For 30 days the "deleted" audio still exists (encrypted): whoever wants immediate deletion chooses "Delete permanently".
- The Trash is local: in phase 4 the `trashed_at` state is not synced as a deletion until it becomes permanent.
