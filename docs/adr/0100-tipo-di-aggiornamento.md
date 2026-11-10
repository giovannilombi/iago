# ADR-0100 — Tipo di aggiornamento deciso a ogni release, con il perché nelle note

- Stato: accettato
- Data: 2026-11-10
- Modifica: ADR-0056 (aggiornamenti: le versioni maggiori non sono più obbligatorie solo per il numero)
- Riferimenti: richiesta dell'utente del 2026-11-10

## Contesto
- Un aggiornamento era obbligatorio solo quando saliva il primo numero (es. 2.0.0): lo decideva `scripts/release.sh`, e anche l'app per conto suo (`UpdateService.isMajor`).
- Una correzione importante dentro una 1.3.x non si poteva rendere obbligatoria, e una versione maggiore non si poteva lasciare facoltativa.
- Sparkle nasconde «Salta questa versione» solo per gli aggiornamenti *critical*, e IAGO trattava ogni *critical* come obbligatorio.
- Le note non dicevano perché un aggiornamento era obbligatorio.

## Decisione
- **A ogni release l'utente sceglie il tipo**, e Claude Code glielo chiede sempre:
  1. **obbligatorio**, sì o no;
  2. se non è obbligatorio, **si può saltare**, sì o no.
- **I tre tipi** (`scripts/release.sh --update`):
  - `optional`: installa, più tardi, salta. Come le versioni minori di prima;
  - `no-skip`: niente «Salta», ma IAGO non blocca nulla. Nell'appcast è *critical* più `<iago:update>no-skip</iago:update>`;
  - `mandatory`: *critical*. Dopo 2 giorni IAGO non avvia nuove registrazioni finché non si aggiorna (ADR-0056, modifica del 2026-10-30).
- **Le note dicono sempre cosa cambia** (`--notes`, obbligatorio). Per `mandatory` dicono anche **perché è obbligatorio**; per `no-skip`, **perché è importante installarlo** anche se lasciamo tempo (`--why`, obbligatorio). Lo script aggiunge la riga in italiano e inglese e scrive le note a paragrafi nella finestra di Sparkle.
- **Lo script si ferma** se manca `--update`, `--notes` o, per i due tipi che lo richiedono, `--why`. Per una versione maggiore ricorda che di solito è obbligatoria, ma la scelta resta all'utente.
- **L'app** (`UpdateService.isMandatory`) considera obbligatorio un aggiornamento *critical* senza `no-skip`. Il numero di versione da solo non lo rende più obbligatorio.

## Conseguenze
- Una correzione urgente si può rendere obbligatoria anche in una 1.3.x. Le versioni installate la riconoscono già, perché leggono *critical* da sempre.
- **`no-skip` funziona dalla 1.3.3-beta**, la prima versione con questa modifica. Le versioni precedenti lo trattano come obbligatorio, con il blocco dopo 2 giorni: finché qualcuno usa una versione più vecchia, conviene `optional` o `mandatory`.
- Le versioni fino alla 1.3.2-beta considerano ancora obbligatoria ogni versione maggiore, qualunque sia il tipo scelto.
- Le regole sono in `CLAUDE.md` e in `README-collaborators.md` › Fare una release.
