# ADR-0033 — Generic import, Teams transcripts, and attachments in notes

- Status: accepted (user requests, 2026-10-12)
- Date: 2026-10-12
- Spec references: FR-30, FR-31, sec. 3.20, 7.6, FR-170; ADR-0019

## Context
The phase 1 import accepted only audio and video. The user wants a single "Import" for everything, considers Teams meeting transcripts valuable material, and wants to paste or drag images, screenshots, and documents into notes. Part of this was planned for phase 2 (documents, `IAGOIngest`): it is brought forward.

## Decision
- **`IAGOIngest` module** (depends only on `IAGOCore`): local extraction to Markdown. Images with Vision OCR (it-IT, en-US, language correction), PDFs with PDFKit and OCR for pages without text (`## Pagina N`), DOCX/RTF/HTML with `NSAttributedString` (headings, lists, bold, italic, links), TXT/MD directly. No network.
- **"Import…"** routes each file:
  - audio and video → item to transcribe; from video **only the audio** is kept (user's choice);
  - meeting transcripts (Teams `.vtt` and `.docx`, recent format "Name  0:03" and old one with `-->`) → `Transcript` with the speakers' **real names**; if the same import contains the recording of the same meeting (the only one imported or the one with the most similar name), it becomes **the main transcript** of that item, otherwise an item of its own; the original file remains as an `original_transcript` asset. Whisper stays optional ("Re-transcribe" replaces, with confirmation). From a recording's detail view: "Attach Teams transcript…";
  - other readable files → `document` item, "unfiled", with the original (`original_document` or `original_image`) and Markdown (`content_md`), status `ready`.
- **Attachments in notes**: by dragging, pasting, or with "Attach file…", the extracted text goes into the note as Markdown; for each file IAGO **asks** whether to keep only the text or the original too (useful for Gantt charts and diagrams). Originals are encrypted `note_attachment` assets tied to the note (`asset.note_id`, migration `v4-attachments`), openable from the note and deleted with it.

## Consequences
- Brought forward from phase 2: the `IAGOIngest` module, `document` items, OCR.
- Still in phase 2: email (`.eml`, pasted, email screenshots), an automatic correctable version of the Markdown (`content_md_auto`), highlighted low-confidence OCR zones, links between items.
- Recording/transcript matching happens only in the same import or by hand: a date-based heuristic is postponed.
