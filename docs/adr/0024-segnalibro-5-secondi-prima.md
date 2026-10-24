# ADR-0024 — "Segna momento" punta a 5 secondi prima del clic

- Stato: accettato (richiesta dell'utente durante i test della fase 0)
- Data: 2026-10-12
- Riferimenti spec: FR-05; ADR-0018

## Contesto
FR-05 crea il segnalibro "al timestamp corrente". Nell'uso reale il momento interessante è già passato quando l'utente reagisce: lo riconosce, apre il menu, eventualmente tiene premuto ⌥ per la nota. Un segnalibro al momento del clic arriva quindi qualche secondo dopo ciò che si voleva segnare.

## Decisione
- Il segnalibro (con o senza nota) si colloca **5 secondi prima del clic**, misurati sulla timeline della registrazione (le pause sono escluse).
- Il riferimento è l'istante in cui si sceglie "Segna momento" o "Segna momento con nota…"; il tempo speso a scrivere la nota non sposta il segnalibro.
- Se mancano meno di 5 secondi dall'inizio della registrazione il segnalibro va a 0: non attraversa il confine con la registrazione precedente ("Nuova registrazione").
- Il valore è una costante (`RecordingSession.bookmarkLookback`); potrà diventare un'impostazione.

## Conseguenze
- Deroga a FR-05 ("timestamp corrente").
- I segnalibri importati in fase 1 nella tabella `marker` hanno già il tempo anticipato: l'import non deve correggerli.
- Nella riproduzione/trascrizione il segnalibro precede di qualche secondo la frase detta al clic: è il comportamento voluto.
