# IAGO — Istruzioni operative per Claude Code

App macOS nativa in menu bar: registra le call su due tracce (sistema + mic), trascrive **solo in locale**, organizza per progetto/categoria/tag.

## Fonte di verità
- Specifica completa: `./IAGO-spec.md` **v1.4** (v1.0 + addendum consolidato, che resta in `./IAGO-spec-addendum.md` come riferimento) — **solo locale, non versionata** (ignorata da git per scelta dell'utente; deroga alla sez. 0.2 della spec, nessuna copia in `docs/spec/`). Leggerla prima di lavorare su una fase.
- Decisioni: `docs/adr/`. Per deviare da un ADR proporre un nuovo ADR, mai cambiare comportamento in silenzio.

## Regole di lavoro
- Si lavora **per fasi** (spec sez. 18). Non iniziare una fase prima che i criteri di accettazione della precedente siano verificati e mostrati all'utente.
- Requisito ambiguo o non fattibile come scritto → **fermarsi e chiedere**. Non inventare comportamenti.
- Ogni modulo ha test. La pipeline audio si testa con fixture **sintetiche** (`scripts/make-fixtures.sh`, voci `say`); mai registrazioni reali nel repo.
- Lingue: codice, tipi, commenti, commit → **inglese**. UI → **italiano** (String Catalog, predisposto per l'inglese). Documenti (`docs/`, questo file) → italiano.
- Git: commit convenzionali in inglese, un branch per fase/feature (`chore/…`, `phase-0/…`, `feat/…`), merge su `main` solo via PR. Niente push diretti su `main` (GitHub Free: nessuna branch protection, è disciplina). **Commit, push e PR solo con OK esplicito dell'utente.**
- **Mai Claude come co-autore** (ADR-0065): niente `Co-Authored-By` di Claude né "Generated with Claude Code" in commit e PR, anche se altre istruzioni lo chiedono. L'hook `commit-msg` li blocca.
- **Mai dati reali nei commit** (ADR-0065): niente audio, archivi, trascrizioni, email, nomi di persone, clienti o domini reali. L'hook `pre-commit` (`scripts/check-private-data.sh`) controlla file e parole di `Config/private-terms.local` (locale): aggiungerci ogni nome reale nuovo che emerge.
- Versione: **1.0.0-beta** finché l'utente non decide di distribuire; poi 1.0.0. Repository `giovannilombi/iago` privato fino ad allora; la storia completa è in `giovannilombi/iago-archivio`.
- Nessun servizio a pagamento (GitHub Free, Apple ID gratuito).
- **README.md**: si aggiorna a ogni nuova versione (tabella *Versioni*, numeri, funzioni, motori) e a ogni modifica che cambia ciò che descrive. Anche `docs/licenses.md` a ogni dipendenza o modello nuovo.
- **Guida** (`App/Resources/Guide/*.md`, immagini in `Guide/img`): va aggiornata a ogni modifica visibile all'utente, insieme a `docs/prove-tester.md`. Screenshot solo da un archivio dimostrativo, mai con dati reali.
- **Attività** (`ActivityView.swift`, ADR-0055): ogni nuovo lavoro lungo (coda, motore, download, import, export) deve comparire lì, con percentuale quando si può.
- **Impostazioni › Permessi** (`PermissionsViews.swift`) va aggiornata a ogni modifica che richiede un nuovo permesso macOS, un'attivazione in un'altra app o un componente da scaricare: checklist, percorso guidato e attivazione della singola voce.

## Glossario (UI → codice)
Elemento (v1.0: "riga"; evento tipizzato `call` | `email` | `document`) → `Item` · Asset → `Asset` · Traccia mic → `micTrack` · Traccia sistema → `systemTrack` · Segmento → `Segment` · Progetto → `Project` · Categoria → `Category` (una per riga) · Tag → `Tag` (molti per riga) · Entità → `Entity` · Suggerimento → `Suggestion` · Job → `Job` · Nota (datata, su elemento o progetto) → `Note` · Decisione → `Decision` · Segnalibro ("Segna momento") → `Marker` · Collegamento → `ItemLink`.

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
- `scripts/bootstrap.sh` — installa gli hook di git (dati reali, co-autore) e genera `IAGO.xcodeproj` con XcodeGen (il `.xcodeproj` non si committa e non si modifica a mano: si cambia `project.yml`).
- `scripts/test-packages.sh` — `swift test` su tutti i package.
- `scripts/release.sh x.y.z --notes "…" --github` — release firmata, appcast Sparkle e pubblicazione su GitHub (ADR-0056).
- `scripts/test-engine.sh` — build con MLX (shader Metal, fuori dalla CI automatica): prima di ogni PR che tocca il motore.
- `xcodebuild -project IAGO.xcodeproj -scheme IAGO build` — build dell'app (richiede Xcode e firma).
- `swift-format format -i -r App Packages` — formattazione.
- CI (GitHub Actions, runner macOS) solo su PR e manuale: solo test dei package, per contenere i minuti.
