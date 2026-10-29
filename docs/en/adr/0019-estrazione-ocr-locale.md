# ADR-0019 — Text extraction and OCR exclusively local

- Status: accepted
- Date: 2026-10-11
- Spec references: v1.4 sec. 3.20–3.21, 7.6; addendum C.1, H.19

## Context
Emails and documents contain information as confidential as calls. Cloud OCR or conversion services would violate the local-first principle.

## Decision
Extraction only with system frameworks and local code: PDFKit, Vision (OCR, `it-IT` + `en-US`), `NSAttributedString` for DOCX/RTF/HTML, a local MIME parser for `.eml`. The original (encrypted) and the derived MD are kept; if the user corrects the MD, the automatic version is kept so that it can be restored.

## Consequences
- OCR quality tied to Vision and to the macOS version; low-confidence areas highlighted in the UI.
- New `asset.kind` values: `original_eml`, `original_image`, `original_document`, `content_md`, `content_md_auto`, `extraction_json`.
