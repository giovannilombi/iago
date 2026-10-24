# ADR-0005 — Trascrizione esclusivamente locale, motori intercambiabili

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 3.6 (FR-50), 7.1, 17.5

## Contesto
Le call contengono informazioni riservate. Un fallback cloud, anche occasionale, violerebbe il principio "nulla esce dal Mac senza azione esplicita".

## Decisione
La trascrizione avviene solo in locale, senza alcun fallback cloud. I motori stanno dietro al protocollo `TranscriptionEngine`: `WhisperCppEngine` (default iniziale, large-v3-turbo, italiano forzato con opzione "automatica") e `ParakeetEngine` via FluidAudio. Il default definitivo si fissa con un ADR dopo il benchmark della fase 0 (decisione aperta B).

## Conseguenze
- Modelli da scaricare (solo su azione dell'utente, URL fissi, SHA-256) e da gestire su disco.
- Prestazioni legate all'hardware; obiettivo: nettamente più veloce del tempo reale su M3 Pro.
- Cambiare motore non tocca il resto dell'app.
