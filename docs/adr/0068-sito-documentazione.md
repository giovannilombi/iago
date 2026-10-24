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

## Modifica del 2026-10-24 (due livelli e allineamento)
- **Due livelli**, con il selettore **Uso | Tecnico** nella barra in alto:
  - **Uso:** la guida dell'app (copiata da `App/Resources/Guide`, quindi sempre identica a quella interna) più installazione, scorciatoie, problemi e log. Ogni capitolo ha in alto il link alla pagina tecnica corrispondente.
  - **Tecnico:** `docs/tecnica` (architettura, dati, cattura, trascrizione, importazione, intelligenza, motore, Claude e MCP, privacy e rete, distribuzione, sviluppo, qualità), più ADR, stato, prove, licenze, progetti, benchmark e storia delle fasi.
- **La guida dentro l'app resta solo d'uso:** niente dettagli tecnici o di costruzione; lo stile resta quello attuale.
- **Allineamento a ogni commit:**
  - la parte funzionale del sito *è* la guida dell'app: non può divergere;
  - l'hook `commit-msg` blocca un commit che cambia il codice dell'app o dei pacchetti senza toccare `App/Resources/Guide` o `docs/`, salvo una riga `Docs: <motivo>`;
  - a ogni PR che tocca la documentazione la CI compila il sito (i link rotti fanno fallire la build); a ogni push su `main` il sito si ripubblica, quando il repository è pubblico.
- I documenti di progetto prima esclusi (ADR, stato, prove, benchmark, progetti, fasi, licenze) entrano nel livello Tecnico; resta fuori solo `docs/testing`.
- Diagrammi mermaid con `vitepress-plugin-mermaid` 2.0.17 e `mermaid` 11.4.1.
