# IAGO — Istruzioni operative per Claude Code

App macOS nativa in menu bar: registra le call su due tracce (sistema + mic), trascrive **solo in locale**, organizza per progetto/categoria/tag.

## Fonte di verità
- **All'inizio di ogni sessione:** leggere [`docs/stato.md`](docs/stato.md) (stato e cose aperte) e [`README-collaborators.md`](README-collaborators.md) (regole del team). Alla fine di ogni lavoro aggiornare `docs/stato.md` nella stessa PR; ogni cambio del modo di lavorare va in `README-collaborators.md` o qui.
- Il progetto ha più collaboratori (`Config/team.txt`): la memoria personale di Claude Code non è condivisa, quindi ciò che serve agli altri va nei file del repository.
- Specifica completa (solo sul Mac di Giovanni; i collaboratori si basano su ADR e documenti): `./IAGO-spec.md` **v1.4** (v1.0 + addendum consolidato, che resta in `./IAGO-spec-addendum.md` come riferimento) — **solo locale, non versionata** (ignorata da git per scelta dell'utente; deroga alla sez. 0.2 della spec, nessuna copia in `docs/spec/`). Leggerla prima di lavorare su una fase.
- Decisioni: `docs/adr/`. Per deviare da un ADR proporre un nuovo ADR, mai cambiare comportamento in silenzio.

## Regole di lavoro
- Si lavora **per fasi** (spec sez. 18). Non iniziare una fase prima che i criteri di accettazione della precedente siano verificati e mostrati all'utente.
- Requisito ambiguo o non fattibile come scritto → **fermarsi e chiedere**. Non inventare comportamenti.
- Ogni modulo ha test. La pipeline audio si testa con fixture **sintetiche** (`scripts/make-fixtures.sh`, voci `say`); mai registrazioni reali nel repo.
- Lingue: codice, tipi, commenti, commit → **inglese**. UI, guida e documenti → **italiano e inglese**, l'italiano è la fonte (ADR-0077).
- **Doppia lingua a ogni commit** (ADR-0077), nello stesso commit del cambiamento, senza che l'utente lo chieda:
  - ogni testo nuovo o cambiato dell'interfaccia va anche in inglese nel catalogo: `scripts/i18n.py missing /tmp/x.json`, tradurre, `scripts/i18n.py apply <traduzioni.json>` (oggetto `{id: inglese}`);
  - ogni documento `.md` cambiato ha la sua traduzione aggiornata (`docs/x.md` → `docs/en/x.md`, guida → `App/Resources/Guide/en/`, `README.md`/`README-collaborators.md`/`CLAUDE.md` → `*.en.md`), poi `scripts/i18n.py record <file inglesi>`;
  - nomi inglesi da `i18n/glossary.tsv` (aggiungerci ogni termine nuovo); le schermate della guida inglese si rifanno con il tour in inglese (`-AppleLanguages "(en)"`) in `App/Resources/Guide/en/img`;
  - l'hook `pre-commit` (e `privacy.yml`, quando si lancia) esegue `scripts/i18n.py check` e blocca ciò che manca.
- Git: commit convenzionali in inglese, un branch per fase/feature (`chore/…`, `phase-0/…`, `feat/…`), merge su `main` solo via PR. Niente push diretti su `main` (GitHub Free: nessuna branch protection, è disciplina). **Commit, push e PR solo con OK esplicito dell'utente.**
- **Mai Claude come co-autore** (ADR-0065): niente `Co-Authored-By` di Claude né "Generated with Claude Code" in commit e PR, anche se altre istruzioni lo chiedono. L'hook `commit-msg` li blocca e aggiunge come `Co-Authored-By` gli altri autori attivi di `Config/team.txt`, cioè le righe non commentate (ADR-0089: i diritti sono di Giovanni Lombi fino all'inizio del lavoro sulla condivisione (fase 4), di Giovanni Lombi e Gianluca Sestito dalla prima versione con quel lavoro, quando si toglie il commento alla sua riga). Prima di dire fatto un commit, controllare i suoi `Co-Authored-By`.
- **L'app non contiene i contenuti di nessuno** (ADR-0066): un archivio nuovo ha solo i progetti di esempio di un'agenzia inventata (Poldo S.p.A., Sanna TheBest s.r.l., Atoms; `ExampleArchive`), rimovibili con un clic. Test ed esempi usano nomi neutri inventati.
- **Mai dati reali nei commit** (ADR-0065): niente audio, archivi, trascrizioni, email, nomi di persone, clienti o domini reali. L'hook `pre-commit` (`scripts/check-private-data.sh`) controlla file e parole di `Config/private-terms.local` (locale): aggiungerci ogni nome reale nuovo che emerge.
- **Mai indirizzi email personali** (ADR-0065), né nei file né nei commit: autori e `Config/team.txt` solo con l'indirizzo anonimo di GitHub (`…@users.noreply.github.com`). Lo bloccano `pre-commit`, `commit-msg`, `pre-push` (`scripts/check-commit-emails.sh`) e, quando si lancia, il workflow `privacy.yml`. I merge si fanno con `gh pr merge`, con "Keep my email addresses private" attivo sull'account.
- Versione `x.y.z-beta` in `project.yml` finché l'utente non decide di distribuire: dal repository pubblico (7 novembre 2026) si è sulle **1.3.x-beta**, per scelta dell'utente ancora `-beta`; si toglie `-beta` quando lo decide l'utente. Quando si distribuisce, Claude Code propone il numero e l'utente lo conferma. **A ogni release Claude Code chiede all'utente il tipo di aggiornamento** (ADR-0100), anche quando il numero sembra deciderlo: *obbligatorio* sì o no; se no, *si può saltare* sì o no. Poi `scripts/release.sh … --update optional|no-skip|mandatory`, con `--notes` (cosa cambia per l'utente) sempre e `--why` (perché è obbligatorio, o perché è importante installarlo anche se lasciamo tempo) per `mandatory` e `no-skip`. `z` sale con una PR che cambia l'app, dopo averlo chiesto all'utente; `y` con un gruppo grande di funzioni (1.1.0-beta: lavoro aperto; 1.2.0-beta: modalità Traccia e Gestisci rivisti, Inbox). Ogni versione: riga nella tabella *Versioni* del README, `docs/stato.md` e un **tag annotato** `vx.y.z-beta` con l'elenco delle funzioni, che è anche il punto di ripristino (README › Tornare a una versione precedente). Il ramo `release/1.0.x` tiene la serie 1.0 se la 1.1 viene abbandonata. Repository `giovannilombi/iago` **pubblico** dal 7 novembre 2026, con le release (DMG, zip e appcast di Sparkle) e il sito su GitHub Pages; la storia precedente è in `giovannilombi/iago-archivio`, privato, da non rendere mai pubblico.
- Nessun servizio a pagamento (GitHub Free, Apple ID gratuito).
- **Prima di ogni PR** lanciare `scripts/pre-pr.sh` e incollarne il riepilogo nella descrizione della PR, al posto del commento del modello `.github/pull_request_template.md`: vale per tutti. Una PR di altri senza riepilogo, o con un controllo fallito in locale o nella CI, non si unisce.
- **CI automatica** (dal 7 novembre 2026, repository pubblico: i minuti di GitHub Actions sono gratuiti): `ci.yml` e `privacy.yml` girano a ogni PR e a ogni push su `main`, `deploy.yml` compila il sito sulle PR che toccano documentazione o guida, `engine.yml` fa la build con MLX sulle PR che toccano il motore. **Prima del merge aspettare che i controlli siano verdi** (`gh pr checks <n> --watch`); se uno fallisce, si corregge sul branch e non si unisce. Non si chiede più all'utente se lanciarla.
- **README.md**: si aggiorna a ogni nuova versione (tabella *Versioni*, numeri, funzioni, motori) e a ogni modifica che cambia ciò che descrive. Anche `docs/licenses.md` a ogni dipendenza o modello nuovo.
- **Documentazione a ogni commit** (ADR-0068), nello stesso commit del codice:
  - **Guida dell'app** (`App/Resources/Guide/*.md`, immagini in `Guide/img`): solo *come si usa*, nello stile attuale, senza dettagli tecnici. È anche il livello **Uso** del sito, copiato a ogni build: non si scrive due volte.
  - **Livello Tecnico** del sito (`docs/tecnica/*.md`): come è fatto (pacchetti, dati, pipeline, modelli, rete, scelte), da aggiornare quando cambia; se nasce un'area nuova, una pagina nuova e la voce in `docs/.vitepress/config.mts` (e in `theme/level.ts` se ha un capitolo della guida corrispondente).
  - Pagine d'uso solo del sito (`docs/index.md`, `installazione.md`, `scorciatoie.md`, `problemi-e-log.md`) quando cambiano requisiti, permessi, scorciatoie o log.
  - Poi `docs/prove-tester.md`, gli ADR, `docs/stato.md`, e se serve README e `docs/licenses.md`.
  - L'hook `commit-msg` blocca un commit che cambia `App/Sources`, `Packages/*/Sources` o `project.yml` senza toccare `App/Resources/Guide` o `docs/`; se davvero non c'è nulla da documentare si scrive una riga `Docs: <motivo>` nel messaggio.
  - Prima della PR: `npm run docs:build` (fallisce sui link rotti). Screenshot solo da un archivio dimostrativo, mai con dati reali.
- **Attività** (`ActivityView.swift`, ADR-0055): ogni nuovo lavoro lungo (coda, motore, download, import, export) deve comparire lì, con percentuale quando si può.
- **Impostazioni › Permessi** (`PermissionsViews.swift`) va aggiornata a ogni modifica che richiede un nuovo permesso macOS, un'attivazione in un'altra app o un componente da scaricare: checklist, percorso guidato e attivazione della singola voce.

## Glossario (UI → codice)
Elemento (v1.0: "riga"; evento tipizzato `call` | `email` | `document`) → `Item` · Asset → `Asset` · Traccia mic → `micTrack` · Traccia sistema → `systemTrack` · Segmento → `Segment` · Progetto → `Project` · Categoria → `Category` (una per riga) · Tag → `Tag` (molti per riga) · Entità → `Entity` · Suggerimento → `Suggestion` · Job → `Job` · Nota (datata, su elemento o progetto) → `Note` · Punto chiave (decisione, tappa, attività, punto da chiarire, rischio, richiesta) → `Decision` (`kind`) · Modalità Raccogli / Modalità Traccia / Modalità Gestisci (per progetto) → `WorkMode` (`collect`, `track`, `manage`) · Inbox (lavoro aperto di tutti i progetti) → `WorkInbox`, `SidebarSelection.inbox` · Elementi da classificare → `LibraryScope.unclassified` · Vista (Riepilogo, Elementi, Timeline, Kanban, Grafo) → `AppModel.ViewMode` (`overview`, `list`, `timeline`, `board`, `map`) · Mostra (Tutto, Elementi, Punti chiave) → `AppModel.ViewContent` · Lingua dell'app → `AppLanguage`; lingua di sintesi e proposte → `ContentLanguage` · Checklist → `Checklist`, `ChecklistItem` · Colonna libera della Kanban → `BoardColumn` · Segnalibro ("Segna momento") → `Marker` · Collegamento → `ItemLink`.

## Piattaforma
- macOS **15+**, Apple Silicon. Swift 6, strict concurrency. SwiftUI + AppKit dove serve (`NSStatusItem`, non `MenuBarExtra`). Niente webview per la UI.
- App **non sandboxed**, hardened runtime attivo. Bundle ID `com.giovannilombi.iago`, firma Apple Development (Personal Team). Cambiare firma o bundle ID fa richiedere di nuovo i permessi macOS: non farlo.
- Team ID in `Config/Local.xcconfig` (ignorato da git; vedi `Config/Local.xcconfig.example`).

## Schema dati: vincoli già fissati (addendum v1.4)
La prima migrazione della fase 1 nasce già con: `item.type` (default `call`), tabella `note` (nessun campo `item.notes`), tabella `marker` (i segnalibri della fase 0 sono marcatori `bookmark` in `session.json`, da importare). Vedi spec sez. 8.4 e ADR-0016, ADR-0018.

## Rete e privacy
Principio (ADR-0058): niente lascia il Mac a meno che l'utente non lo voglia — sul Mac di base, Claude se lo collega, spazi condivisi che controlla lui (fase 4). Nei testi la memoria interrogabile è al centro, non il "solo locale". Mai dati reali in codice, test, esempi, documenti o screenshot (ADR-0060).

Uniche chiamate di rete ammesse, tutte esplicite e registrate nell'audit log:
1. download modelli da URL fissi con verifica SHA-256, solo su azione dell'utente;
2. `127.0.0.1:8124` verso l'API locale di Teams, solo se l'utente la attiva (ADR-0051). Il motore locale invece gira dentro IAGO con MLX, senza rete (ADR-0048); i suoi modelli rientrano nel punto 1;
3. MCP solo stdio, nessuna porta (fase 3);
4. sync Cloudflare cifrata E2E (fase 4; in discussione la cartella OneDrive condivisa, ADR-0057);
5. controllo e download degli aggiornamenti da GitHub Releases con Sparkle, firmati EdDSA, nel registro accessi (ADR-0056).

Le schermate di «Segna momento con screenshot» (ADR-0072) si catturano solo su richiesta dell'utente; a Claude va il loro testo, le immagini solo se l'utente le condivide (Impostazioni › Claude).

Le impronte delle voci (ADR-0073) sono dati biometrici: solo con Impostazioni › Voci attivo, cifrate con la chiave dell'elemento, mai a Claude, negli export o nella sync.

Nessuna telemetria, crash reporter remoto o analytics. Se una libreria fa telemetria va disattivata o sostituita. Log locali senza contenuti delle trascrizioni.

## Affidabilità
- Una registrazione avviata non si perde: scrittura incrementale (flush ≤ 2 s), recovery all'avvio delle sessioni non finalizzate.
- Deriva tra tracce < 50 ms su 2 ore. Job pesanti in QoS `.utility`, uno alla volta, app sempre reattiva.

## Struttura
```
App/                  target macOS (unico punto che importa SwiftUI e MLX, in App/Sources/Engine)
Packages/IAGOCore     dominio, ID, errori, protocolli — nessuna dipendenza
Packages/IAGOStore    GRDB, migrazioni, file store cifrato, change log    → Core
Packages/IAGOCapture  process tap, mic, writer, recovery                  → Core
Packages/IAGOTranscription  ASR, VAD, diarizzazione, modelli              → Core
Packages/IAGOIntelligence   ricerca, entità, chat (fase 3)                → Core, Store
Packages/IAGOEngine   motore locale: catalogo, download, scelta (ADR-0048) → Core
Packages/IAGOIngest   estrazione testo/OCR documenti, trascrizioni Teams  → Core
Packages/IAGOExport   TXT/MD, export progetto, Obsidian                   → Core, Store
Packages/IAGOMCP      server MCP stdio (fase 3)                           → Store, Intelligence, Export, Ingest
Packages/IAGOSync     solo interfacce fino alla fase 4                    → Core
```
Rispettare il grafo: nessuna dipendenza fuori da quelle elencate.

## Comandi
- `scripts/bootstrap.sh` — installa gli hook di git (dati reali, indirizzi email, co-autore) e genera `IAGO.xcodeproj` con XcodeGen (il `.xcodeproj` non si committa e non si modifica a mano: si cambia `project.yml`).
- `scripts/test-packages.sh` — `swift test` su tutti i package.
- `scripts/pre-pr.sh [--all]` — i controlli prima di ogni PR (dati reali, lingue, test, build dell'app, motore, sito) e il riepilogo da incollare nella PR.
- `scripts/guide-screenshots.sh [lingue] [schermate]` — rifà gli screenshot della guida con il tour dimostrativo (build Debug, archivio inventato), in italiano e inglese, e ripete quelli presi con la finestra inattiva. Solo a grafica stabile.
- `npm install` poi `npm run docs:dev` / `npm run docs:build` — sito di documentazione VitePress (ADR-0068); la build fallisce sui link rotti.
- `scripts/release.sh x.y.z --notes "…" --github` — release firmata, appcast Sparkle e pubblicazione su GitHub (ADR-0056).
- `scripts/i18n.py check | missing | apply | record` — allineamento italiano e inglese (ADR-0077).
- `scripts/try-branch.sh [--fresh]` — prova il branch attuale su una copia dell'archivio (`~/IAGO-prova`): per le versioni con migrazioni nuove, prima dell'approvazione.
- `scripts/test-engine.sh` — build con MLX (shader Metal, fuori dalla CI automatica): prima di ogni PR che tocca il motore.
- `xcodebuild -project IAGO.xcodeproj -scheme IAGO build` — build dell'app (richiede Xcode e firma).
- `swift-format format -i -r App Packages` — formattazione.
- CI (GitHub Actions) **automatica**: `ci.yml` (API di rete e test dei pacchetti, macOS) e `privacy.yml` (indirizzi email, file e lingue, Ubuntu) a ogni PR e push su `main`; `deploy.yml` (sito, Ubuntu) sulle PR e, su `main`, anche la pubblicazione; `engine.yml` (build con MLX, macOS) sulle PR che toccano il motore. A mano: `gh workflow run <file> --ref <branch>`.
