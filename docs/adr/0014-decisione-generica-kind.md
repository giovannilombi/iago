# ADR-0014 — Modello `decision` generico (`kind`)

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 FR-157; addendum H.14

## Contesto
Azioni (action item) e questioni aperte hanno la stessa forma di una decisione: testo, data, fonte, persone, stato, evoluzione.

## Decisione
La tabella `decision` ha un campo `kind` (`decision` | `action` | `open_question`). In v1 la UI espone solo `decision`.

## Conseguenze
- Azioni e questioni aperte si aggiungono in futuro senza migrazioni di schema.
- Le query e le viste filtrano sempre per `kind`.
