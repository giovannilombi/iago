# ADR-0057 — Sync and sharing through the company OneDrive folder

- Status: proposed (draft for phase 4; it would replace the backend of ADR-0012). Detailed design to be discussed: `docs/design/sync-cartella-condivisa.md`
- Date: 2026-10-21
- Spec references: sec. 13 (sync and sharing), 8.1 (sync fields, `change_log`); ADR-0012, ADR-0056; proposal by a colleague of the user, 2026-10-21

## Context
- The spec foresees end-to-end encrypted sync on Cloudflare (ADR-0012).
- The user's company already has a **shared OneDrive**, synced to every Mac by the OneDrive app. The user wants to use it, provided that:
  - it is **agnostic about who creates**;
  - later on there is **"super admin" control** that can delete and manage for everyone.
- In a company domain, encryption is optional.
- The data model is already ready: all tables have `created_at`, `updated_at`, `deleted_at`, `version` and `device_id`, and every change ends up in `change_log`.

## Proposed decision
### How it works
- **No shared database.** A SQLite file in a synced folder gets corrupted. Each Mac keeps its own archive and the shared folder contains only **immutable** files.
- **Each Mac writes only into its own subfolder**, so OneDrive never creates conflicting files:
  ```
  OneDrive - Azienda/IAGO/
    spazio.json                        name, format version, encryption yes/no
    membri.json                        who takes part (name, email); written only by admins
    dispositivi/<device-id>/modifiche/<hlc>.json   change batches, append-only
    dispositivi/<device-id>/istantanee/<hlc>.json  compact state, now and then
    asset/<sha256>                     transcripts, documents and, if chosen, audio (content-addressed)
    Aggiornamenti/                     the app releases (ADR-0056)
  ```
- **Publishing:** every few seconds IAGO writes a batch with the `change_log` rows of the shared projects.
- **Receiving:** IAGO reads the other devices' batches and applies them idempotently.
- **Conflicts:** as in the spec, last-writer-wins per field with a hybrid logical clock. For texts (notes, edited summaries) both versions are kept and the conflict is flagged.
- **Snapshots:** periodic, so a new Mac does not have to reread the whole history.
- **Network:** IAGO makes no connection; OneDrive handles the network. The "Network and privacy" rule remains valid: point 4 of CLAUDE.md would become "sync through a shared folder".

### What is shared
- **Per project:** "Share with the company" (`sharing_enabled`). It includes items, notes, key points, summaries and transcripts. Projects that are not shared stay only on the Mac.
- **Audio:** per space, "text only" or "audio too". Audio takes up a lot of space: it can be downloaded on demand.
- **Author:** each row carries author and device. Anyone in the space sees and edits the shared projects, that is, it is agnostic about who creates.

### Admin control (to be done separately)
- In `membri.json` some members are **admins**.
- An admin can:
  - delete for everyone, with a tombstone that every Mac applies;
  - archive projects;
  - remove a member.
- Admin actions are signed with a key of the admin, so a file edited by hand in the folder is not enough to delete other people's work.

### Encryption
- **Optional**, decided when the space is created.
- Recommended at least for audio: a group key, distributed with an invitation and kept in each member's Keychain.
- The content of the folder is in any case already protected by the company's OneDrive permissions.

## To be decided with the user
1. Sharing **project by project**, or everything shared by default.
2. Audio yes, no or on demand.
3. Encryption: none, audio only, or everything.
4. Who is admin, and whether admin control comes in right away or later.
5. Web and mobile: the spec foresaw them with Cloudflare. With OneDrive they are not there. For now they are given up: Mac only.

## Consequences
- No new external service, no Cloudflare account, no cost. It uses the infrastructure and permissions the company already has.
- It works as long as members have the folder synced. Propagation times are those of OneDrive (seconds or minutes).
- ADR-0012 would be superseded for the backend; the rules on conflicts, tombstones and client-side search remain valid.

## Change of 2026-10-21 (user's directions)
- **Collaborative:** a shared project no longer belongs to its author but to the space. Anyone with access to the folder uses it freely.
- **Visible sign:** the cloud folder icon next to the project, like the Claude logo.
- **Materials readable outside IAGO too** (Markdown and audio). No encryption by default: the protection is that of the company folder.
- **Agnostic:** any cloud folder, not only OneDrive, because IAGO will also be distributed outside the company.
- **Control per space:** the owner and the admins have actions signed with personal keys; it does not depend on the OneDrive administrator.
