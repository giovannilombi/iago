# Collaborare a IAGO

Questa guida è per chi entra nel progetto senza conoscerne la storia. Spiega cos'è IAGO, quali documenti usiamo e a cosa servono, le regole che seguiamo, come si prova l'app e come si lavora con Claude Code.

> **Regola delle regole.** Il modo di lavorare vive in questi file, non nella testa di qualcuno né nella memoria personale di Claude Code. Chi cambia una regola, un'abitudine o un passaggio del flusso lo scrive qui (o in `CLAUDE.md`, se riguarda Claude Code) nella stessa PR in cui lo applica. Così usiamo tutti gli stessi.

## 1. Cos'è IAGO, in una pagina
- Un'app nativa per macOS (menu bar) che fa da **memoria interrogabile del lavoro**: registra e trascrive le call, raccoglie email, documenti e note, ne estrae decisioni e attività, e risponde alle domande citando le fonti.
- **I dati sono dell'utente.** Restano sul Mac di base; escono solo se l'utente lo sceglie (Claude, o in futuro uno spazio condiviso che controlla). Nessuna telemetria.
- **L'app non contiene contenuti.** Chi la installa trova un archivio vuoto con un solo esempio di struttura (ADR-0066). Tutto quello che ognuno di noi registra o importa resta suo e non entra mai nel repository.
- Il [README](README.md) descrive funzioni, architettura, motori, numeri misurati, installazione e crediti.

## 2. I documenti e a cosa servono

| File | Cosa contiene | Quando si aggiorna |
|---|---|---|
| [`README.md`](README.md) | Cos'è IAGO, funzioni, architettura, installazione, versioni, crediti | A ogni versione e a ogni modifica che cambia ciò che descrive |
| `README-collaborators.md` (questo) | Regole, documenti, flusso di lavoro, prove | A ogni cambio del modo di lavorare |
| [`CLAUDE.md`](CLAUDE.md) | Istruzioni per Claude Code: regole, glossario, struttura, comandi. Vale per tutti noi | A ogni regola nuova |
| [`docs/stato.md`](docs/stato.md) | **Il punto di ripartenza**: versione, cosa è aperto, ultime modifiche | Alla fine di ogni lavoro, nella stessa PR |
| [`docs/adr/`](docs/adr/README.md) | Le decisioni (ADR), con contesto, alternative e conseguenze; l'indice ha lo stato di ognuna | Per ogni decisione nuova o cambiata |
| [`docs/prove-tester.md`](docs/prove-tester.md) | Le prove manuali, in ordine, pensate per chi non conosce l'app | A ogni funzione nuova o modificata |
| [`App/Resources/Guide/`](App/Resources/Guide) | La guida dentro l'app (capitoli in Markdown, screenshot in `img/`); è anche la guida del sito | A ogni modifica visibile all'utente |
| `docs/index.md`, `docs/installazione.md`, `docs/scorciatoie.md`, `docs/problemi-e-log.md` | Le pagine d'uso solo del sito di documentazione (ADR-0068) | Quando cambiano requisiti, installazione, permessi, scorciatoie o log |
| [`docs/tecnica/`](docs/tecnica) | Il livello **Tecnico** del sito: architettura, dati, pipeline, modelli, rete, sviluppo | Nello stesso commit di ogni modifica a come è fatta l'app |
| [`docs/licenses.md`](docs/licenses.md) | Dipendenze e modelli, con versioni e licenze | A ogni dipendenza o modello nuovo |
| [`docs/design/`](docs/design) | Progetti di funzioni ancora da decidere (es. la condivisione) | Durante la discussione |
| [`docs/benchmarks/`](docs/benchmarks) | Misure di velocità e qualità (solo numeri, mai contenuti delle call) | A ogni misura nuova |
| [`docs/phase-0.md`](docs/phase-0.md) … [`phase-3.md`](docs/phase-3.md) | Cosa è stato fatto in ogni fase e come è stato verificato | Chiusa la fase, solo correzioni |
| [`docs/installazione.md`](docs/installazione.md) | Installare IAGO senza notarizzazione | Se cambia la procedura |
| [`Config/team.txt`](Config/team.txt) | Gli autori, usati per i co-autori dei commit | Quando entra qualcuno |

**File solo locali, mai nel repository:**
- `IAGO-spec.md` e `IAGO-spec-addendum.md`: la specifica originale, di Giovanni. Le decisioni che contano sono riportate negli ADR; per un dubbio sulla specifica si chiede a lui.
- `HANDOVER.md`: appunti personali di sessione.
- `Config/Local.xcconfig`: il proprio Team ID di firma.
- `Config/private-terms.local`: i nomi reali (persone, clienti, domini) che ognuno vuole bloccare nei commit.
- `Test-recordings/`, `bench-out/`, `Models/`: registrazioni di prova, risultati delle prove, modelli scaricati.

## 3. Regole

### I dati
- **Mai dati reali nel repository**: niente audio, archivi, trascrizioni, email, nomi di persone, clienti o domini reali. Negli esempi e nei test si usano nomi inventati e neutri (Cliente Test, Acme, Rossi…).
- Gli screenshot della guida si fanno solo dall'archivio dimostrativo della build Debug (ADR-0061), mai dal proprio archivio.
- Un controllo automatico prima di ogni commit (`scripts/check-private-data.sh`) blocca file e parole vietate. Aggiungi a `Config/private-terms.local` i nomi reali che usi nel tuo lavoro: il file resta sul tuo Mac.

### Autori e attribuzione
- Dalle versioni successive alla 1.0.0-beta i diritti sono di **Giovanni Lombi e Gianluca Sestito** (ADR-0065). Chi fa il commit ne è l'autore; l'altro viene aggiunto da solo come `Co-Authored-By`, leggendo `Config/team.txt`.
- **Mai un'IA come autore o co-autore**, e nessuna riga "Generated with…" nei commit e nelle PR. Il controllo dei commit li blocca.

### Git e GitHub
- Un branch per lavoro (`feat/…`, `fix/…`, `docs/…`, `chore/…`), da `main` aggiornato.
- Su `main` si entra solo con una **pull request**, con la CI verde e l'OK dell'altro. Niente push diretti su `main`: GitHub Free non lo impedisce, è disciplina.
- Commit convenzionali in inglese (`feat: …`, `fix: …`, `docs: …`).
- **Build da sorgente e DMG:** chi sviluppa usa la propria build compilata dal codice (si aggiorna con `git pull` e una nuova build; non cerca aggiornamenti automatici). Il DMG delle release è per chi non sviluppa: per provarlo si usa un altro account utente o un altro Mac, perché due copie di IAGO sullo stesso account si contendono permessi e archivio.
- **Mai un indirizzo email personale**, né nei file né nei commit (ADR-0065): si firma con l'indirizzo anonimo di GitHub. In GitHub › Settings › Emails vanno attivati "Keep my email addresses private" (così anche i merge fatti dal sito usano l'indirizzo anonimo) e "Block command line pushes that expose my email". I controlli di git bloccano commit e push con un indirizzo personale, e il workflow Privacy fa lo stesso su GitHub.
- La CI gira sulle PR che toccano codice e lancia i test dei pacchetti. I minuti macOS sono pochi (GitHub Free li conta 10 volte), quindi non va lanciata a vuoto.

### Lingue
- Codice, tipi, commenti e commit: **inglese**.
- Interfaccia, guida e documenti: **italiano e inglese** (ADR-0077). L'italiano è la fonte; l'inglese si aggiorna **nello stesso commit**:
  - stringhe dell'app: `scripts/i18n.py missing /tmp/mancanti.json`, traduci, `scripts/i18n.py apply traduzioni.json`;
  - documenti: `docs/x.md` → `docs/en/x.md`, guida → `App/Resources/Guide/en/`, `README.md`, `README-collaborators.md` e `CLAUDE.md` → `*.en.md`; poi `scripts/i18n.py record <file inglesi>`;
  - i nomi inglesi sono in `i18n/glossary.tsv`.
- L'hook `pre-commit` e la CI eseguono `scripts/i18n.py check`: se manca una traduzione il commit si ferma e dice cosa manca. Con Claude Code la traduzione la fa lui durante il lavoro.
- Frasi brevi e dirette, in entrambe le lingue.

### Decisioni (ADR)
- Una decisione rilevante si scrive come ADR in `docs/adr/`, con il formato dell'indice, e si aggiunge una riga all'indice.
- Un ADR accettato non si riscrive: si aggiunge una sezione "Modifica del …" oppure un ADR nuovo che lo sostituisce.
- Un requisito ambiguo si chiarisce prima di scrivere codice.

### Codice
- macOS 15+, Apple Silicon, Swift 6 con concorrenza rigorosa, SwiftUI con AppKit dove serve. Nessuna webview.
- Il grafo dei pacchetti è fisso (vedi `CLAUDE.md` › Struttura): nessuna dipendenza fuori da quelle elencate.
- Ogni modulo ha i suoi test. La pipeline audio si prova con fixture sintetiche (`scripts/make-fixtures.sh`, voci `say`).
- **Rete:** solo le chiamate elencate in `CLAUDE.md` › Rete e privacy, tutte esplicite e registrate. Niente telemetria.
- Ogni lavoro lungo compare in Attività; ogni permesso nuovo in Impostazioni › Permessi.

### Documentazione a ogni commit
La documentazione si aggiorna **nello stesso commit** del codice, non dopo:
- **Guida dell'app** (`App/Resources/Guide`): solo come si usa, nello stile attuale, senza dettagli tecnici. È anche il livello Uso del sito, quindi le due non possono divergere.
- **Livello Tecnico del sito** (`docs/tecnica`): come è fatto, quando cambia.
- **ADR** per le decisioni, `docs/prove-tester.md` per le prove, `docs/stato.md` per lo stato.

Il controllo dei commit blocca un commit che tocca il codice dell'app o dei pacchetti senza toccare la guida o `docs/`. Se davvero non c'è niente da documentare (per esempio un refactoring interno), si aggiunge al messaggio una riga `Docs: <motivo>`.

## 4. Preparare il Mac
1. Xcode con Swift 6, poi `brew install xcodegen swift-format`.
2. `cp Config/Local.xcconfig.example Config/Local.xcconfig` e inserire il proprio Team ID (un Apple ID gratuito basta).
3. `cp Config/private-terms.local.example Config/private-terms.local` e scriverci i nomi reali da bloccare.
4. `git config user.name` e `git config user.email` con il proprio indirizzo **anonimo di GitHub** (`<id>+<utente>@users.noreply.github.com`, in GitHub › Settings › Emails), lo stesso scritto in `Config/team.txt`. Mai un indirizzo personale nel repository: il controllo dei commit lo blocca.
5. `scripts/bootstrap.sh`: installa i controlli di git e genera `IAGO.xcodeproj` (il progetto Xcode non si committa: si cambia `project.yml`).
6. `scripts/test-packages.sh` per i test, `scripts/install-app.sh` per installare la propria build in `/Applications`.
7. Per il sito di documentazione serve Node.js (`brew install node`): `npm install`, poi `npm run docs:dev` (anteprima con ricarica automatica su `http://localhost:5173/iago/`) o `npm run docs:build`.

Comandi utili, con la spiegazione, nel README › Sviluppo e in `CLAUDE.md` › Comandi.

## 5. Stato degli ADR
L'indice completo con lo stato è in [`docs/adr/README.md`](docs/adr/README.md). Oggi:
- **Accettati e fatti:** da 0001 a 0077, tranne quelli sotto. Il sito di 0068 è pronto ma andrà online solo con il repository pubblico.
- **Da decidere:**
  - **0057**, progetti condivisi tramite una cartella cloud: è il cuore della fase 4. Quando viene accettato, supera il backend di 0012 (sincronizzazione su Cloudflare).
  - **0067**, MiniCPM al posto di Qwen 3.5 4B o in aggiunta: servono le prove descritte nell'ADR.
- **Accettato, da completare:** **0060**, pubblicazione del repository. Il repository pulito c'è già (0065); manca il passaggio a pubblico con la prima release, quando si decide di distribuire.
- **Non più validi:** **0053** ritirato (la cancellazione dell'eco di macOS toglieva il microfono a Teams), **0064** rifiutato (la pulizia dell'eco dopo la registrazione peggiorava la voce).

Cosa resta da fare, in ordine, è in [`docs/stato.md`](docs/stato.md).

## 6. Prove
- Le prove manuali sono in [`docs/prove-tester.md`](docs/prove-tester.md), ordinate e scritte per chi non conosce l'app.
- **Ogni tester ha una issue su GitHub**, "Prove 1.2.2-beta — Nome Cognome", con tutte le prove come caselle da spuntare. Si spunta la casella quando la prova funziona; per un problema si scrive un commento con il numero della prova (es. "3h.4"), cosa si è fatto e cosa si è visto. Tutti i collaboratori leggono le issue e i commenti.
- Una nuova tornata di prove (nuova beta, nuovo tester) si apre con `scripts/new-test-round.sh "Nome Cognome" 1.2.2-beta`: la issue prende le prove dalla versione attuale di `docs/prove-tester.md`.
- Un difetto trovato diventa una issue a parte, collegata alla prova; la correzione arriva con una PR che la chiude.
- Per le prove non servono dati reali. Chi prova con le proprie call tiene quei contenuti per sé: nei commenti si descrive il comportamento, non il contenuto.

## 7. Lavorare con Claude Code
- Lo sviluppo finora è stato fatto con Claude Code. `CLAUDE.md` contiene le istruzioni che Claude legge all'inizio di ogni sessione: valgono per chiunque lo usi su questo repository.
- **Ripartire con una sessione pulita:** chiedere a Claude di leggere `CLAUDE.md`, [`docs/stato.md`](docs/stato.md) e questa guida, poi gli ADR dell'area su cui si lavora.
- La memoria personale di Claude Code e gli appunti locali non sono condivisi: tutto quello che serve agli altri va in questi file.
- Claude propone, le persone decidono: commit, push, PR e merge solo con l'OK di chi lavora; per le scelte che cambiano il prodotto si scrive o si aggiorna un ADR.
- Alla fine di ogni lavoro: aggiornare `docs/stato.md`, e se è cambiato qualcosa nel modo di lavorare, questa guida o `CLAUDE.md`.

## 8. Il sito di documentazione
- È fatto con VitePress (ADR-0068) e sarà su `https://giovannilombi.github.io/iago/`. GitHub Free non pubblica siti di repository privati, quindi andrà online quando il repository diventerà pubblico; fino ad allora si guarda in locale con `npm run docs:dev`.
- **Due livelli** con il selettore **Uso | Tecnico** in alto:
  - **Uso:** la guida, copiata dai capitoli dell'app (`App/Resources/Guide`): si modifica lì, mai nel sito. Più installazione, scorciatoie, problemi e log.
  - **Tecnico:** `docs/tecnica` più ADR, stato, prove, licenze, progetti, benchmark e fasi.
- Ogni capitolo della guida ha il link alla pagina tecnica corrispondente (`docs/.vitepress/theme/level.ts`).
- A ogni PR che tocca la documentazione la CI compila il sito; a ogni push su `main` lo ripubblica (quando il repository è pubblico).

## 9. Fare una release
- La versione è in `project.yml`, nella forma `x.y.z-beta`. Il terzo numero sale con una PR che cambia l'app (si chiede a Giovanni), il secondo con un gruppo grande di funzioni. Alla distribuzione si toglie `-beta`.
- Ogni versione ha un **tag annotato** (`git tag -a v1.0.1-beta -m "…funzioni…"`) che fa da punto di ripristino per codice, guida e documentazione; vedi README › *Tornare a una versione precedente*. Il ramo `release/1.0.x` tiene la serie 1.0.
- `scripts/release.sh <versione> --notes "…" --github` compila, firma l'archivio per Sparkle (la chiave è nel Portachiavi di Giovanni) e pubblica la release. Funziona solo con il repository pubblico, cioè quando si decide di distribuire.
- A ogni release si aggiorna la tabella Versioni del README.
