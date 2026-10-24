# ADR-0002 — Due tracce separate, mix solo per l'ascolto

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 3.2 (FR-10), 6, 7.2, 17.2

## Contesto
Una registrazione mixata perde l'informazione su chi parla: la diarizzazione su un mix è meno affidabile e non distingue l'utente dagli altri. Con tracce separate la voce dell'utente è nota per costruzione.

## Decisione
Ogni registrazione produce due tracce sincronizzate: `systemTrack` (audio in uscita da tutte le app, escluso IAGO) e `micTrack` (microfono in uso in call). La traccia mic è sempre lo speaker "Io". Un mix viene generato in finalizzazione solo per l'ascolto; la pipeline di trascrizione lavora sulle tracce separate.

## Conseguenze
- La diarizzazione serve solo sulla traccia sistema; lo speaker "Io" è certo.
- Serve sincronizzazione precisa (host time, riempimento buchi con silenzio, deriva < 50 ms).
- Con altoparlanti la traccia mic capta eco: servono cancellazione d'eco e filtro in trascrizione.
- Spazio su disco circa triplo rispetto a una traccia sola (mic + sistema + mix).
