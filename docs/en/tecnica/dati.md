# Data and archive

## Where it lives
Everything is in `~/Library/Application Support/IAGO/`:

| Path | Content |
|---|---|
| `iago.sqlite` | the database (GRDB): items, projects, notes, decisions, segments, indexes, settings, job queue |
| `Items/<id>/` | the files of each item, encrypted: audio tracks, transcripts, original documents, attachments |
| `tmp/sessions/` | recordings in progress, written continuously; emptied after finalization |
| `tmp/scratch/` | unencrypted temporary files (playback, engine work), emptied at launch |

The database is excluded from Time Machine (it contains the search index in plain text); the encrypted files are not.

## Model
- An **item** (`Item`, ADR-0018) is a typed event: `call`, `email`, `document`. It has a project, a category (one) and tags (many), streams (many, ADR-0038).
- **Hierarchy** client › project › stream (ADR-0038). A project without a client goes under "No client"; an item filed without a project goes under "Undefined" (ADR-0035).
- Dated **notes**, on an item or on a project, including voice notes (ADR-0016, ADR-0021, ADR-0039). **Bookmarks** (`Marker`) with the time in the call (ADR-0024).
- **Key points** (`Decision`) with a kind (decision, task, milestone…), source down to the minute, people, and supersession chains, including multiple ones (ADR-0013, ADR-0014, ADR-0046, ADR-0052).
- **Open work** (ADR-0074): in `decision` owner and wait (`owner_id`, `waiting_on_id` pointing to `entity`), `due_at`, `waiting_until`, `priority`, `starts_at`, `estimate`, `severity`, `happened_at`, `outcome`, `outcome_kind`, `derived_from_id`, `recurrence`, `closed_at`; tables `decision_dependency`, `checklist` and `checklist_item` (sub-items of a task or project lists), `board_column` and `board_place` (free columns of each board); `project.work_mode`.
- **Suggestions** from the engine or from Claude, always to be confirmed (ADR-0009). Summaries and suggestions have `origin` (`engine`, `claude` or, for speaker names, `voice`) and `model`; a key point confirmed from a suggestion keeps `model` (ADR-0070). **Links** between items (`ItemLink`).
- **Voices** (ADR-0073, only if enabled): `item_voice` holds the voiceprint of each speaker of a call, encrypted with the item's key; `voice` only the person's name. A person's voiceprint is the average of their calls, computed on the fly: deleting a call removes it. Voices do not enter the `change_log` or exports.
- **Ready for sync** (ADR-0008): every row has `created_at`, `updated_at`, `deleted_at`, `version`, `device_id`; every change ends up in `change_log`.

## Migrations
Twenty-one so far, from `v1` to `v21-work` (open work, ADR-0074: only new columns and tables); `v20-voices` adds voiceprints (ADR-0073); `v19-screenshots` adds call screenshots with their minute and recognized text (ADR-0072); `v18-provenance` records who produced summaries, suggestions and confirmed key points (ADR-0070). A migration is never modified after release: a new one is added. Before installing a build that brings new migrations onto a user's archive, a backup is made.

## Encryption
- **Block-encrypted files** with AES-GCM (ADR-0027): reads and writes happen in chunks, even for large files, without decrypting them entirely in memory.
- **One key per item**, in turn protected by a master key in the macOS **Keychain** (ADR-0028).
- **Permanent deletion = key destruction** (*crypto-shredding*): the files become unreadable even in copies and backups.
- 30-day **Trash** (ADR-0030); a discarded recording stays recoverable for one hour (ADR-0032).

## Backups and exports
- **Encrypted backup** with a password chosen by the user: a single file with the whole archive, for an external drive or a new Mac (ADR-0041).
- Project **export** in Markdown (also designed for an LLM), optional **Obsidian mirror**, TXT/MD of a transcript (`IAGOExport`).
- **Access log:** downloads, Claude reads and writes, exports, backups and updates.

## Starter example
A new, empty archive receives, only once, an example structure without content (Test Client, Test Pj. 1 with two streams, Test Pj. 2), to show how work is organized (ADR-0066). The app contains no other data.
