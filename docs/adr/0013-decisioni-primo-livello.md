# ADR-0013 — Decisioni come oggetti di primo livello

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 3.16 (FR-150…157); addendum H.13

## Contesto
Le decisioni prese in call, email o note sono l'informazione più richiesta a posteriori ("cosa abbiamo deciso su X?"), ma evolvono nel tempo e la loro fonte può essere eliminata (audio cancellato, elemento rimosso).

## Decisione
La decisione (`decision`) è un oggetto autonomo con testo, data (`decided_at`), progetto, persone, fonte facoltativa (elemento + timestamp, oppure nota), stato (`active` | `superseded` | `cancelled`) e relazione "supera" (`supersedes_id`). Se la fonte viene eliminata la decisione resta e perde solo il collegamento.

## Conseguenze
- Vista "Decisioni", marcatori in timeline e sezione dedicata nell'export di progetto.
- Una decisione che ne supera un'altra porta quella precedente a `superseded` automaticamente.
- L'eliminazione di un elemento deve gestire i riferimenti (`source_item_id` a null) senza perdere decisioni.
