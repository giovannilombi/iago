# ADR-0077 — Italiano e inglese, sempre allineati

- Stato: accettato (1.2.2-beta)
- Data: 2026-10-29
- Riferimenti: ADR-0054 (sintesi per categoria), ADR-0061 (guida integrata), ADR-0066 (esempio iniziale), ADR-0068 (sito e documentazione a ogni commit); richiesta dell'utente del 2026-10-29

## Contesto
- IAGO era solo in italiano: interfaccia, guida, sito, documenti di sviluppo e testi scritti dal motore (sintesi, proposte, risposte). Il String Catalog era predisposto, ma quasi vuoto.
- L'utente vuole l'app e tutta la documentazione in italiano e inglese, con la lingua scelta al primo avvio e cambiabile in modo semplice, e la doppia lingua mantenuta a ogni modifica.

## Decisione
- **L'italiano resta la lingua di partenza**, l'inglese la segue. Ogni testo nuovo o cambiato si scrive in entrambe le lingue nello stesso commit.
- **App:**
  - le stringhe sono estratte nel String Catalog (`SWIFT_EMIT_LOC_STRINGS`) e tradotte in inglese;
  - **la lingua si sceglie al primo avvio**, come primo passo, con i due nomi scritti ciascuno nella sua lingua;
  - **si cambia in Impostazioni › Generale › Lingua**. macOS applica la lingua all'avvio (`AppleLanguages` dell'app), quindi IAGO chiede di riavviarsi;
  - la guida integrata ha una cartella per lingua: `App/Resources/Guide` (italiano) e `App/Resources/Guide/en`, con le sue schermate.
- **Ciò che IAGO scrive segue la lingua dell'app:** sintesi, proposte, sintesi di stato, risposte di «Chiedi a IAGO», tag nuovi.
  - Le istruzioni al motore restano in italiano e dicono in che lingua scrivere (`ContentLanguage` in IAGOCore, salvata in `UserDefaults` dall'app).
  - I modelli di sintesi hanno una versione inglese con gli stessi id e le stesse sezioni (`SummaryLibrary.englishLibrary`).
  - Le citazioni restano come sono state dette.
- **Nomi dati da IAGO:** l'esempio iniziale e le categorie predefinite con un nome italiano (SAL, Interna, Altro) prendono il nome nella lingua dell'app quando la lingua cambia, se l'utente non li ha rinominati (`Archive.relabelDefaults`). Le famiglie di categorie restano salvate con il nome italiano e si mostrano tradotte.
- **«Io»:** la propria voce senza un nome si chiama «Io» in italiano e «Me» in inglese; entrambi indicano sempre l'utente.
- **Documentazione:** ogni documento ha la sua versione inglese:
  - `docs/x.md` → `docs/en/x.md`;
  - `README.md`, `README-collaborators.md` e `CLAUDE.md` → `*.en.md`;
  - la guida → `App/Resources/Guide/en/`.

  Il sito VitePress ha l'italiano alla radice e l'inglese sotto `/en/`, con il selettore della lingua.
- **Glossario:** `i18n/glossary.tsv` fissa i nomi inglesi dell'interfaccia e dei concetti, per l'app e per i documenti.
- **Allineamento controllato in automatico:** `scripts/i18n.py check` gira nell'hook `pre-commit` e nella CI. Blocca se:
  - un documento italiano non ha la traduzione;
  - un documento italiano è cambiato dopo la sua traduzione;
  - una stringa del catalogo non ha l'inglese;
  - una stringa del codice non è ancora nel catalogo.

  `i18n/sources.json` ricorda da quale testo italiano viene ogni file inglese.
- **La traduzione la scrive chi fa la modifica**, in pratica Claude Code durante il lavoro, prima del commit: niente servizi di traduzione in rete né a pagamento (ADR-0058).

## Conseguenze
- Il lavoro su ogni modifica comprende la traduzione. `scripts/i18n.py missing` e `apply` passano per Xcode per le stringhe dell'app; `record` registra i documenti tradotti.
- Le date nelle trascrizioni («entro venerdì») e i nomi degli speaker generati («Speaker 1», «Stanza») restano riconosciuti in italiano: sono dati delle call, non dell'interfaccia.
- Gli strumenti MCP per Claude restano descritti in italiano: Claude li capisce in entrambe le lingue.
- La prima traduzione di tutto (circa 1.700 stringhe e 70.000 parole di documenti) è stata fatta con la 1.2.2-beta.
