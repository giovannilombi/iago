# ADR-0019 — Estrazione di testo e OCR esclusivamente locali

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 3.20–3.21, 7.6; addendum C.1, H.19

## Contesto
Email e documenti contengono informazioni riservate quanto le call. Servizi di OCR o conversione in cloud violerebbero il principio local-first.

## Decisione
Estrazione solo con framework di sistema e codice locale: PDFKit, Vision (OCR, `it-IT` + `en-US`), `NSAttributedString` per DOCX/RTF/HTML, parser MIME locale per `.eml`. Si conservano l'originale (cifrato) e il MD derivato; se l'utente corregge il MD, la versione automatica viene conservata per poterla ripristinare.

## Conseguenze
- Qualità OCR legata a Vision e alla versione di macOS; zone a bassa confidenza evidenziate nella UI.
- Nuovi `asset.kind`: `original_eml`, `original_image`, `original_document`, `content_md`, `content_md_auto`, `extraction_json`.
