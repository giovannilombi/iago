# ADR-0016 — Note multiple e datate

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 3.18 (FR-170…176); addendum H.16

## Contesto
Un campo note unico per riga non rappresenta informazioni che arrivano in momenti diversi dopo una call (un'email, un aggiornamento, una decisione presa più tardi), né informazioni legate al progetto ma non a un elemento.

## Decisione
Tabella `note`: zero o più note per elemento, oppure legate al solo progetto; testo markdown, data `noted_at` modificabile, tipo facoltativo (`note`, `email`, `late_decision`, `update`), modalità di inserimento (`typed` | `voice`). Sostituisce `item.notes`, che non viene mai creato (nessun dato esistente da migrare: il database nasce in fase 1 già con `note`).

## Conseguenze
- Le note compaiono in timeline alla loro data, nella sezione "Addendum" degli export, e possono essere promosse a decisione.
- "Elimina tutto" su un elemento con note chiede se eliminarle o spostarle sul progetto.
