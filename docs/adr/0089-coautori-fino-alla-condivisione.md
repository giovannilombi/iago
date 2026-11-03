# ADR-0089 — Co-autori dei commit fino alla condivisione

- Stato: accettato
- Data: 2026-11-03
- Riferimenti: ADR-0065 (repository pulito, autori e diritti)

## Contesto
- ADR-0065 dava i diritti a Giovanni Lombi fino alla 1.0.0-beta e a entrambi gli autori «dalle versioni successive». L'hook `commit-msg` aggiungeva quindi Gianluca Sestito come `Co-Authored-By` a ogni commit.
- La regola dell'utente è un'altra: i diritti sono di Giovanni Lombi fino all'inizio del lavoro sulla condivisione (fase 4), di entrambi dalla prima versione con quel lavoro, la prima fatta insieme.

## Decisione
- Fino ad allora i commit hanno come autore solo Giovanni Lombi.
- In `Config/team.txt` la riga di Gianluca Sestito resta commentata. L'hook salta le righe che iniziano con `#`, quindi non la aggiunge.
- Nel commit della prima versione con il lavoro sulla condivisione si toglie il commento. Da lì ogni commit nomina entrambi, come prevede ADR-0065.

## Conseguenze
- I commit già su `main` dopo la 1.0.0-beta, fino alla 1.2.13-beta, nominano anche Gianluca Sestito. Restano così: riscriverli vorrebbe dire ricreare il repository (le PR chiuse conservano i vecchi commit).
- Prima di dire fatto un commit si controllano i suoi `Co-Authored-By`.
