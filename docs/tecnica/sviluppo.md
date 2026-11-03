# Sviluppo

Le regole complete del team sono in [`README-collaborators.md`](https://github.com/giovannilombi/iago/blob/main/README-collaborators.md) e le istruzioni per Claude Code in [`CLAUDE.md`](https://github.com/giovannilombi/iago/blob/main/CLAUDE.md). Qui il riassunto tecnico.

## Preparare il Mac
1. Xcode con Swift 6, `brew install xcodegen swift-format node`.
2. `Config/Local.xcconfig` dal suo `.example`, con il proprio Team ID.
3. `Config/private-terms.local` dal suo `.example`, con i nomi reali da bloccare nei commit.
4. `git config user.email` con l'indirizzo anonimo di GitHub (`<id>+<utente>@users.noreply.github.com`), uguale a quello in `Config/team.txt`; in GitHub › Settings › Emails attivare "Keep my email addresses private" e "Block command line pushes that expose my email".
5. `scripts/bootstrap.sh`: installa i controlli di git e genera `IAGO.xcodeproj`.

## Comandi
| Comando | A cosa serve |
|---|---|
| `scripts/bootstrap.sh` | hook di git + progetto Xcode da `project.yml` |
| `scripts/test-packages.sh` | `swift test` su tutti i pacchetti |
| `scripts/test-engine.sh` | build dell'app con MLX e shader Metal (prima delle PR sul motore) |
| `scripts/install-app.sh` | Release firmata installata in `/Applications` |
| `scripts/try-branch.sh [--fresh]` | prova il branch attuale su una **copia** dell'archivio (`~/IAGO-prova`, opzione Debug `-IAGOTrialRoot`): l'archivio vero non si tocca |
| `scripts/check-network-apis.sh` | nessuna API di rete fuori da quelle ammesse |
| `scripts/check-private-data.sh --all` | nessun dato reale nei file |
| `scripts/check-commit-emails.sh main..HEAD` | nessun indirizzo email personale nei commit |
| `scripts/make-fixtures.sh` | fixture audio sintetiche con le voci `say` |
| `scripts/new-test-round.sh "Nome" [versione]` | issue di prove per un tester |
| `scripts/release.sh x.y.z --github` | release firmata e appcast |
| `npm run docs:dev` / `docs:build` | sito di documentazione |
| `swift-format format -i -r App Packages` | formattazione |

## Regole che contano
- **Branch e PR:** un branch per lavoro, merge su `main` solo con PR, test e build del sito fatti in locale e OK dell'altro.
- **Lingue:** codice e commit in inglese, interfaccia e documenti in italiano.
- **Decisioni:** ogni scelta rilevante è un [ADR](/adr/); un ADR accettato non si riscrive, si modifica con una sezione datata o si sostituisce.
- **Dati:** mai dati reali nel repository (ADR-0065); l'app non contiene contenuti (ADR-0066).
- **Indirizzi email:** mai uno personale, né nei file né nei commit; si firma con l'indirizzo anonimo di GitHub (ADR-0065).
- **Autori:** fino al lavoro sulla condivisione (fase 4) i commit hanno come autore solo Giovanni Lombi; da quella versione nominano anche Gianluca Sestito, aggiunto dall'hook quando la sua riga in `Config/team.txt` non è più commentata (ADR-0089); mai un'IA.

## Documentazione a ogni commit
Ogni commit che cambia il comportamento dell'app aggiorna la documentazione nello stesso commit:
- **Guida dell'app** (`App/Resources/Guide`), solo come si usa: è anche il livello **Uso** di questo sito, copiata a ogni build.
- **Livello Tecnico** di questo sito (`docs/tecnica`), se cambia come è fatto: pacchetti, dati, pipeline, modelli, rete.
- **ADR** se cambia una decisione, `docs/prove-tester.md` per le prove, `docs/stato.md` per lo stato.

## Italiano e inglese (ADR-0077)
L'italiano è la fonte; ogni testo cambiato si aggiorna anche in inglese, nello stesso commit.
- **Stringhe dell'app:** il String Catalog (`App/Resources/Localizable.xcstrings`) si riempie con l'estrazione di Xcode (`SWIFT_EMIT_LOC_STRINGS`). `scripts/i18n.py missing mancanti.json` elenca le stringhe senza inglese; tradotte in un oggetto `{id: inglese}`, `scripts/i18n.py apply traduzioni.json` le scrive nel catalogo.
- **Documenti:**
  - `docs/x.md` ha la traduzione in `docs/en/x.md`, la guida in `App/Resources/Guide/en/` con le schermate in inglese;
  - `README.md`, `README-collaborators.md` e `CLAUDE.md` hanno `*.en.md`;
  - dopo aver tradotto, `scripts/i18n.py record <file inglesi>` registra in `i18n/sources.json` la versione italiana da cui vengono.
- **Nomi:** `i18n/glossary.tsv` fissa i nomi inglesi di interfaccia e concetti.
- **Controllo:** `scripts/i18n.py check`, nell'hook `pre-commit` e in `privacy.yml` (quando si lancia). Blocca se:
  - manca una traduzione;
  - l'italiano è cambiato dopo la traduzione;
  - una stringa del catalogo non ha l'inglese;
  - una stringa del codice non è ancora nel catalogo.
- **Sito:** VitePress con l'italiano alla radice e l'inglese sotto `/en/` (`locales` in `docs/.vitepress/config.mts`); `scripts/docs-sync-guide.mjs` copia entrambe le guide.

## Controlli di git
`scripts/bootstrap.sh` attiva gli hook in `scripts/git-hooks`:
- `pre-commit`: niente dati reali nei file (audio, archivi, modelli, nomi di `Config/private-terms.local`, indirizzi dei servizi di posta personali), autore e committer con l'indirizzo anonimo di GitHub, italiano e inglese allineati (`scripts/i18n.py check`);
- `commit-msg`: niente co-autore IA, niente indirizzi email nel messaggio, co-autori del team aggiunti da soli, documentazione nello stesso commit;
- `pre-push`: ricontrolla autore, committer e messaggio di ogni commit che sta per uscire, anche quelli fatti saltando gli hook.

L'hook `commit-msg` blocca anche un commit che tocca il codice dell'app o dei pacchetti senza toccare la documentazione, a meno che il messaggio non contenga una riga `Docs: <motivo>` (per esempio `Docs: refactoring interno, nessun effetto visibile`).

## CI
Tutti i workflow si lanciano **solo a mano** (`gh workflow run <file> --ref <branch>`), quando serve: i minuti di GitHub Free sono pochi e a ottobre 2026 sono finiti. Prima di ogni PR si fanno in locale test dei pacchetti e build del sito; gli hook fanno gli altri controlli.
- `ci.yml`, su macOS: controllo delle API di rete e test dei pacchetti, circa 4 minuti, che GitHub conta 10 volte.
- `deploy.yml`, su Ubuntu: compila il sito; lo pubblica su GitHub Pages da solo a ogni push su `main` solo quando il repository sarà pubblico (da privato il job si salta e non consuma minuti).
- `engine.yml`: build con MLX.
- `privacy.yml`, su Ubuntu: nessun indirizzo email personale nei commit (autore, committer, messaggio) e nei file; italiano e inglese allineati. Pochi secondi; i nomi reali restano un controllo locale, perché il loro elenco non lascia il Mac.
- I test che usano Vision, PDFKit e gli importatori di AppKit hanno un limite di tempo, e ogni pacchetto si ferma dopo 10 minuti con il suo nome.
- I tre test di OCR con Vision **non girano in CI**: sui runner macOS di GitHub Vision si blocca senza errore. Girano sul Mac di chi sviluppa con `scripts/test-packages.sh` (si saltano dove è impostata la variabile `CI`).
- L'HTML importato si converte con il convertitore proprio, senza WebKit, che si bloccava fuori dal thread principale.

## Struttura
```
App/                      target macOS (SwiftUI, AppKit, MLX in App/Sources/Engine)
App/Resources/Guide/      guida dell'app (Markdown + screenshot), fonte del livello Uso del sito
Packages/                 i dieci pacchetti Swift
docs/                     sito (index, installazione, tecnica/), ADR, stato, prove, benchmark, progetti
scripts/                  bootstrap, test, release, controlli, hook di git
Config/                   xcconfig, team, esempi dei file locali
Design/                   logo e icone
```
