# ADR-0032 — "Scarta" durante la registrazione e "Scartate temporanee"

- Stato: accettato (richiesta dell'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: FR-17, FR-20; ADR-0030

## Contesto
FR-17 salva sempre la registrazione allo Stop. L'utente vuole poter buttare una registrazione partita per errore o non utile senza passare dal cestino a 30 giorni, ma con un margine per ripensarci.

## Decisione
- Durante una registrazione, nella barra della finestra e nel menu della barra dei menu, c'è **"Scarta"** (con conferma).
- La registrazione si ferma, viene salvata e cifrata come sempre (nessuna perdita in caso di crash), poi va nel Cestino in una sezione separata, **"Scartate temporanee"** (`item.trash_reason = 'discarded'`), senza pannello post-registrazione.
- Dopo **1 ora** viene eliminata definitivamente (crypto-shredding). Fino ad allora si può ripristinare o eliminare subito. Il controllo delle scadenze del cestino passa da una volta al giorno a ogni 5 minuti.

## Conseguenze
- Deroga a FR-17 per le sole registrazioni scartate.
- Migrazione `v2-discarded` (colonna `item.trash_reason`).
- Se IAGO resta chiuso più di un'ora, la registrazione scartata viene eliminata al successivo avvio.
