# ADR-0033 — Import generico, trascrizioni Teams e allegati nelle note

- Stato: accettato (richieste dell'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: FR-30, FR-31, sez. 3.20, 7.6, FR-170; ADR-0019

## Contesto
L'import della fase 1 accettava solo audio e video. L'utente vuole un unico "Importa" per tutto, considera le trascrizioni delle riunioni Teams materiale prezioso e vuole incollare o trascinare immagini, screenshot e documenti nelle note. Parte di questo era previsto nella fase 2 (documenti, `IAGOIngest`): viene anticipato.

## Decisione
- **Modulo `IAGOIngest`** (dipende solo da `IAGOCore`): estrazione locale in Markdown. Immagini con OCR Vision (it-IT, en-US, correzione linguistica), PDF con PDFKit e OCR per le pagine senza testo (`## Pagina N`), DOCX/RTF/HTML con `NSAttributedString` (titoli, elenchi, grassetto, corsivo, link), TXT/MD diretti. Nessuna rete.
- **"Importa…"** smista ogni file:
  - audio e video → elemento da trascrivere; dal video si conserva **solo l'audio** (scelta dell'utente);
  - trascrizioni di riunione (Teams `.vtt` e `.docx`, formato recente "Nome  0:03" e vecchio con `-->`) → `Transcript` con i **nomi veri** degli speaker; se nello stesso import c'è la registrazione della stessa riunione (l'unica importata o quella con il nome più simile) diventa **la trascrizione principale** di quell'elemento, altrimenti un elemento a sé; il file originale resta come asset `original_transcript`. Whisper resta facoltativo ("Ritrascrivi" sostituisce, con conferma). Dalla scheda di una registrazione: "Allega trascrizione Teams…";
  - altri file leggibili → elemento `document` "da classificare" con originale (`original_document` o `original_image`) e Markdown (`content_md`), stato `ready`.
- **Allegati nelle note**: trascinando, incollando o con "Allega file…" il testo estratto entra nella nota in Markdown; per ogni file IAGO **chiede** se conservare solo il testo o anche l'originale (utile per Gantt e schemi). Gli originali sono asset `note_attachment` cifrati legati alla nota (`asset.note_id`, migrazione `v4-attachments`), apribili dalla nota e eliminati con lei.

## Conseguenze
- Anticipati dalla fase 2: modulo `IAGOIngest`, elementi `document`, OCR.
- Ancora in fase 2: email (`.eml`, incollate, screenshot di email), versione automatica del Markdown correggibile (`content_md_auto`), zone a bassa confidenza OCR evidenziate, collegamenti tra elementi.
- L'abbinamento registrazione/trascrizione avviene solo nello stesso import o a mano: un'euristica sulle date è rimandata.
