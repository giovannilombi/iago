# ADR-0068 — Sito di documentazione con VitePress su GitHub Pages

- Stato: accettato (pubblicazione automatica quando il repository diventa pubblico)
- Data: 2026-10-24
- Riferimenti: ADR-0061 (guida integrata), ADR-0060 e ADR-0065 (repository privato fino alla distribuzione)

## Contesto
- Chi installa IAGO, e chi lo valuta prima di installarlo, ha bisogno di una documentazione leggibile fuori dall'app: requisiti, installazione con "Apri comunque", permessi, uso, scorciatoie, problemi e log.
- La guida per l'utente esiste già dentro l'app (`App/Resources/Guide`) e si aggiorna a ogni modifica visibile: non deve nascere una seconda copia da tenere allineata.

## Decisione
- **VitePress 1.6.3** con radice in `docs/`, `base: '/iago/'`, tema scuro di default, ricerca locale, interfaccia in italiano.
- **Una sola fonte per la guida:** `scripts/docs-sync-guide.mjs` copia i capitoli di `App/Resources/Guide` in `docs/guida/` (con screenshot, logo e icona) prima di ogni build; i file copiati sono ignorati da git. La barra laterale prende i titoli dai capitoli.
- **Pagine solo del sito:** `docs/index.md` (presentazione), `docs/installazione.md` (requisiti, Gatekeeper, permessi, calendario, aggiornamenti, disinstallazione), `docs/scorciatoie.md`, `docs/problemi-e-log.md`.
- **Fuori dal sito** (`srcExclude`): i documenti interni del team, cioè ADR, progetti, benchmark, fasi, stato, prove e licenze. Restano su GitHub.
- **Pubblicazione:** `.github/workflows/deploy.yml`, il workflow ufficiale di VitePress, a ogni push su `main` che tocca la documentazione o la guida.
  - GitHub Free non offre Pages per i repository privati: finché `giovannilombi/iago` è privato i job si saltano e l'attivazione di Pages via API restituisce "plan does not support".
  - Quando il repository diventa pubblico: attivare Pages con `gh api -X POST /repos/giovannilombi/iago/pages -f build_type=workflow` e lanciare il workflow. Il sito sarà su `https://giovannilombi.github.io/iago/`.
- **Comandi:** `npm install`, poi `npm run docs:dev` per lavorare in locale, `npm run docs:build` per la prova completa (fallisce sui link rotti).

## Conseguenze
- Serve Node.js per chi lavora sul sito; l'app e i pacchetti Swift non ne dipendono.
- I minuti delle Actions per il sito girano su Ubuntu, che GitHub Free conta una volta sola (non dieci come macOS).
- A ogni modifica di installazione, permessi, scorciatoie o log si aggiorna anche la pagina del sito corrispondente.
