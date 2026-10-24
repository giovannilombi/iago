# ADR-0031 — Opzione "Più persone nella stanza"

- Stato: accettato (richiesta dell'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: sez. 7.2, FR-41; ADR-0002, ADR-0006

## Contesto
La pipeline assegna tutta la traccia mic allo speaker "Io" e diarizza solo la traccia di sistema (spec 7.2, ADR-0006). Nella prova del blocco 3 due persone nella stessa stanza, entrambe sul microfono del Mac, sono finite tutte sotto "Io".

## Decisione
- Opzione per elemento **"Più persone nella stanza"**, scelta nel pannello post-registrazione o nella scheda quando si trascrive o ritrascrive (default spento).
- Con l'opzione attiva la traccia mic viene diarizzata come quella di sistema. La voce con più parlato è "Io" (`me`); le altre diventano `r2`, `r3`… con etichetta "Stanza 2", "Stanza 3"…, rinominabili come gli altri speaker (FR-41).
- Il filtro eco si applica ai segmenti mic già divisi per speaker.
- Per gli elementi importati (una traccia sola) non cambia nulla: sono già diarizzati per intero.

## Conseguenze
- Deroga a spec 7.2 passo 3 e ad ADR-0006 solo quando l'opzione è attiva.
- La voce principale è scelta per durata: se l'utente parla meno degli altri presenti va rinominata a mano.
- Diarizzazione in più sulla traccia mic: pochi secondi per ora di audio.
