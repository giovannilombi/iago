# ADR-0029 — Registrazioni della fase 0 importate nell'archivio cifrato

- Stato: accettato (scelta confermata dall'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: sez. 9.1; ADR-0007, ADR-0016, ADR-0024

## Contesto
Nella fase 0 le registrazioni finalizzate erano salvate in chiaro in `Recordings/<itemId>/` (`mic.m4a`, `system.m4a`, `mix.m4a`, `session.json`), in attesa della cifratura della fase 1. Lasciarle in chiaro contraddice la sez. 9; cancellarle farebbe perdere call reali dell'utente.

## Decisione
- All'avvio, ogni cartella di `Recordings/` passa dallo stesso percorso delle nuove registrazioni (`RecordingArchiver`): elemento `Unclassified · …` con la data di inizio, tracce cifrate in `Items/<itemId>/`, segnalibri importati nella tabella `marker` (con il tempo già anticipato di 5 s, ADR-0024), pause e cambi di dispositivo in `item.capture_meta`.
- Ogni file in chiaro si cancella solo dopo che la sua copia cifrata è scritta; la cartella si cancella alla fine; `Recordings/` si rimuove quando è vuota.
- Lo stesso percorso archivia all'avvio le registrazioni rimaste in `tmp/finalized/` (crash tra finalizzazione e cifratura): è idempotente.

## Conseguenze
- Dopo il primo avvio della fase 1 non resta audio in chiaro fuori da `tmp/sessions/` (registrazioni in corso).
- L'ID dell'elemento è quello della sessione: un segnalibro o un riferimento della fase 0 resta valido.
- Verificato il 2026-10-12: 23 registrazioni importate, nessun file in chiaro in `Items/`, `Recordings/` rimossa.
