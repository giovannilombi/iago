# ADR-0039 — Project notes, project attachments, and voice notes

- Status: accepted
- Date: 2026-10-13
- Spec references: FR-172…175, FR-210…218, sec. 7.7, 9.3

## Context
Project notes have no item. Attachments, however, were tied by foreign key to `item`, and encryption keys are per item. Voice notes must be transcribed immediately without keeping the audio, and must never be lost.

## Decision
- **Project notes:** `note.item_id` is null and `note.project_id` is set, as the schema provides. They appear in the project timeline at their date, together with the items' notes (FR-175).
- **Project attachments (migration `v8-asset-owner`):**
  - `asset.item_id` becomes the **owner id**, that is an item or a project, and loses the foreign key to `item` (the table is rebuilt).
  - A project gets a key in `item_key` at its first attachment, with the same per-owner encryption.
  - Deleting the project destroys its attachments and its key (crypto-shredding).
- **Voice notes:**
  - **Recording:** microphone only with `AVAudioEngine`, on the default input or on the microphone chosen in the menu bar. The file goes into `tmp/voice-notes/<uuid>.caf`, alongside a JSON that indicates the destination (item, project, note) and the date. The folder is not emptied at launch.
  - **Transcription:**
    - happens immediately, **outside the job queue**: a single track, no diarization, no echo filter;
    - the engine is the same as for calls and processes one audio chunk at a time, so a note fits in between the chunks of a long transcription without waiting for it to finish (FR-211);
    - the same engine chosen in Settings is used. The separate "Voice note engine" setting is postponed as long as the single engine is enough.
  - **Fate of the audio:**
    - it is deleted when the text is saved in the note, or if the user cancels;
    - if transcription fails it stays, with "Retry / Discard audio";
    - leftover recordings (failed or interrupted by a crash) are offered again at launch with "Transcribe and save / Later / Discard audio".
  - **Inserting the text:** in the editor, "Append" (default) or "Replace". The note is marked `input = voice`.
  - **"Voice note…" from the menu bar:**
    - it is a panel that starts listening immediately;
    - the default destination is the last item opened or created, or another recent item or a project;
    - the entry is disabled during a call;
    - if a call starts while dictating, the note is stopped and transcribed first (FR-217).

## Consequences
- Cleanup of dictated text with the local LLM (FR-219) will arrive in Phase 3.
- The encrypted backup (Block 6) must include the project keys present in `item_key`.
