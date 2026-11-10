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
- **Projects in the Trash** (migration `v25-project-trash`, ADR-0099): `project.trashed_at`. Its items go to the Trash with it, with `trash_reason` = `project`, so they disappear from every query that leaves out trashed items; the project's notes, key points, checklists, streams and search rows are left out with `Archive.outsideTrashedProjects`. `restoreProject` puts everything back as it was; after 30 days, or with *Empty Trash*, `deleteProject` deletes it for good (`IAGOStore/ProjectTrash.swift`).
- **Present** (migration `v24-attendees`): `item_attendee` (`item_id`, `name`, `position`), who was at a meeting according to the user (ADR-0031); offered as speaker names, in exports and in *Share*.
- **Speaker names** (migration `v22-speaker-names`): `item_speaker.merged_into`, the speaker of the same call one was joined to; `name_alias` (normalized `alias` → `name`), the nicknames the user said are the same person («Lello» → «Antonello»).
- **Two transcripts** (ADR-0078): `transcript_json` is the main one, read by summaries, suggestions, exports and MCP; `alternate_transcript_json` the other (Teams beside IAGO or vice versa), in its own file `transcript-alt.json`. Swap and removal in `IAGOStore/Transcripts.swift`. Search also indexes the other one: its `search_index` rows have `source_id` `<item>#alt-<teams|iago>-<segment>` (`Archive.indexAlternateTranscript`); the index is rebuilt once on update (`search_index_version` = 2).
- **Summary's transcript** (migration `v23-summary-transcript`): `summary.transcript_source` (`iago`, `teams`) is the main transcript when the summary was written; nil for earlier ones.
- **Ready for sync** (ADR-0008): every row has `created_at`, `updated_at`, `deleted_at`, `version`, `device_id`; every change ends up in `change_log`.

## Migrations
Twenty-five so far, up to `v25-project-trash` (ADR-0099: one column); `v21-work` (open work, ADR-0074: only new columns and tables); `v20-voices` adds voiceprints (ADR-0073); `v19-screenshots` adds call screenshots with their minute and recognized text (ADR-0072); `v18-provenance` records who produced summaries, suggestions and confirmed key points (ADR-0070). A migration is never modified after release: a new one is added. Before installing a build that brings new migrations onto a user's archive, a backup is made.

## Encryption
- **Block-encrypted files** with AES-GCM (ADR-0027): reads and writes happen in chunks, even for large files, without decrypting them entirely in memory.
- **One key per item**, in turn protected by a master key in the macOS **Keychain** (ADR-0028).
- **Permanent deletion = key destruction** (*crypto-shredding*): the files become unreadable even in copies and backups.
- 30-day **Trash** (ADR-0030), also for whole projects (ADR-0099); a discarded recording stays recoverable for one hour (ADR-0032).

## Backups and exports
- **Encrypted backup** with a password chosen by the user: a single file with the whole archive, for an external drive or a new Mac (ADR-0041).
- Project **export** in Markdown (also designed for an LLM), optional **Obsidian mirror**, TXT/MD of a transcript (`IAGOExport`).
- **Share an item** (ADR-0080, `IAGOExport/ItemShare.swift`): the chosen parts (Markdown card, transcripts, audio, tracks, originals, screenshots) decrypted into a temporary folder (`IAGO-Condividi`, emptied at each share), optionally in a zip made with `ditto`, then `NSSharingServicePicker` or a chosen folder. Voice prints are not assets and are never there. In the access log as `export/share`.
- **Access log:** downloads, Claude reads and writes, exports, backups and updates.

## Starter example
A new, empty archive receives, only once, after the language is chosen, the **example projects** (`IAGOStore/ExampleArchive.swift`, ADR-0066): three invented clients with transcribed calls, emails, documents, summaries, key points, suggestions and notes, in the app's language and dated around the day of creation. The items have `capture_meta = example` and do not count in the first steps; the IDs are in the `example_ids` setting and `Archive.removeExample` deletes them. Archives created before 1.2.10-beta keep the old «Test Client» structure.
