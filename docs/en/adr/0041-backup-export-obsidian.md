# ADR-0041 — Encrypted backup, transfer to a new Mac, export, and Obsidian mirror

- Status: accepted
- Date: 2026-10-13
- Spec references: sec. 9.3, 10.4, 11.2, 11.3; FR-90, FR-91, FR-122, FR-191; ADR-0028; user requests (audio export, new Mac)

## Context
The archive is encrypted with a master key in the Keychain (ADR-0028). Losing the Mac or the key would make everything unreadable. The user also wants to share audio, move to a new Mac with an identical archive, give a project to an LLM, and see it in Obsidian.

## Decision
- **Encrypted backup** (`IAGOStore/Backup.swift`):
  - **Format:** a `.iagobackup` file in **Apple Encrypted Archive**, a system format with no external dependencies, with the scrypt + AES-CTR + HMAC profile and LZFSE compression.
  - **Content:** a consistent copy of the database (SQLite backup, valid even while the app is writing), the `Items` folder with the files already encrypted per item (cloned on APFS, so no double space), the master key, and a manifest.
  - **Password:** chosen by the user, at least 10 characters. Apple Archive accepts only very long passwords, so the user's password is stretched with PBKDF2-SHA256 (600,000 iterations) before being passed to scrypt with the archive's random salt.
  - **Recovery:** IAGO does not keep the password and nobody can recover it; the interface says so.
- **Restore:**
  - the file is decrypted and verified immediately (manifest, key, database openable with the current migrations) in `restore-pending`;
  - the swap happens at relaunch, before opening the database;
  - the previous archive **is not deleted**: it goes to `Archivi sostituiti/<data>`, and its key stays in the Keychain as `master-key-before-restore-<data>`;
  - "Restore a backup" is also available on the first onboarding screen, for the new Mac.
- **LLM export** (`ProjectExporter`): a single Markdown file for the current view (project, client, stream, filters) according to spec 11.2/11.3:
  - an index, then the decision log with status, source, and "supersedes" chain;
  - then items and project notes in chronological order, with the heading by type;
  - documents in full or as an excerpt;
  - a token estimate (about one token every 3.6 characters).
- **Audio export:** unencrypted `.m4a` copies, optionally with the `.md` transcript, for the current view or for the whole archive.
- **Obsidian mirror** (`ObsidianMirror`):
  - only from IAGO to the vault, only for enabled projects (with a warning that they are unencrypted), in the `IAGO/` subfolder;
  - one file for each item, project note, and decision, plus notes for each project, client, and person, with wikilinks;
  - IAGO rewrites or removes **only** files with `iago_id` in the front matter, and a user file with the same name is not touched;
  - the update starts 10 seconds after the last change.
- **Correctable Markdown** (FR-191): the first correction keeps the extracted text as `content_md_auto`; "Restore the automatic text" puts it back. Search follows the corrected text.
- **Audit:** every export, Obsidian setting, backup, and restore is recorded in the log (`export`, `backup`), never with the content.

## Consequences
- No network: the automatic network API check stays green.
- A backup contains the master key: its security depends on the password, which the interface asks the user to keep safe.
- Archives in `Archivi sostituiti` are deleted from Settings › Backup and transfer, with the same triple confirmation as projects (warning, typing DELETE, final confirmation). Deletion destroys the folder and its key in the Keychain, and is recorded in the log.
