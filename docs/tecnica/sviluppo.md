# Sviluppo

Le regole complete del team sono in [`README-collaborators.md`](https://github.com/giovannilombi/iago/blob/main/README-collaborators.md) e le istruzioni per Claude Code in [`CLAUDE.md`](https://github.com/giovannilombi/iago/blob/main/CLAUDE.md). Qui il riassunto tecnico.

## Preparare il Mac
1. Xcode con Swift 6, `brew install xcodegen swift-format node`.
2. `Config/Local.xcconfig` dal suo `.example`, con il proprio Team ID.
3. `Config/private-terms.local` dal suo `.example`, con i nomi reali da bloccare nei commit.
4. `git config user.email` uguale all'indirizzo in `Config/team.txt`.
5. `scripts/bootstrap.sh`: installa i controlli di git e genera `IAGO.xcodeproj`.

## Comandi
| Comando | A cosa serve |
|---|---|
| `scripts/bootstrap.sh` | hook di git + progetto Xcode da `project.yml` |
| `scripts/test-packages.sh` | `swift test` su tutti i pacchetti |
| `scripts/test-engine.sh` | build dell'app con MLX e shader Metal (prima delle PR sul motore) |
| `scripts/install-app.sh` | Release firmata installata in `/Applications` |
| `scripts/check-network-apis.sh` | nessuna API di rete fuori da quelle ammesse |
| `scripts/check-private-data.sh --all` | nessun dato reale nei file |
| `scripts/make-fixtures.sh` | fixture audio sintetiche con le voci `say` |
| `scripts/new-test-round.sh "Nome" [versione]` | issue di prove per un tester |
| `scripts/release.sh x.y.z --github` | release firmata e appcast |
| `npm run docs:dev` / `docs:build` | sito di documentazione |
| `swift-format format -i -r App Packages` | formattazione |

## Regole che contano
- **Branch e PR:** un branch per lavoro, merge su `main` solo con PR, CI verde e OK dell'altro.
- **Lingue:** codice e commit in inglese, interfaccia e documenti in italiano.
- **Decisioni:** ogni scelta rilevante è un [ADR](/adr/); un ADR accettato non si riscrive, si modifica con una sezione datata o si sostituisce.
- **Dati:** mai dati reali nel repository (ADR-0065); l'app non contiene contenuti (ADR-0066).
- **Autori:** dopo la 1.0.0-beta ogni commit nomina Giovanni Lombi e Gianluca Sestito (l'hook aggiunge il co-autore); mai un'IA.

## Documentazione a ogni commit
Ogni commit che cambia il comportamento dell'app aggiorna la documentazione nello stesso commit:
- **Guida dell'app** (`App/Resources/Guide`), solo come si usa: è anche il livello **Uso** di questo sito, copiata a ogni build.
- **Livello Tecnico** di questo sito (`docs/tecnica`), se cambia come è fatto: pacchetti, dati, pipeline, modelli, rete.
- **ADR** se cambia una decisione, `docs/prove-tester.md` per le prove, `docs/stato.md` per lo stato.

L'hook `commit-msg` blocca un commit che tocca il codice dell'app o dei pacchetti senza toccare la documentazione, a meno che il messaggio non contenga una riga `Docs: <motivo>` (per esempio `Docs: refactoring interno, nessun effetto visibile`).

## CI
- `ci.yml`, su macOS, solo per le PR che toccano codice: controllo delle API di rete e test dei pacchetti. I minuti macOS contano 10 volte, quindi niente esecuzioni inutili.
- `deploy.yml`, su Ubuntu: compila il sito a ogni PR che tocca la documentazione e lo pubblica su GitHub Pages a ogni push su `main` (quando il repository è pubblico).
- `engine.yml`, solo a mano: build con MLX.
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
