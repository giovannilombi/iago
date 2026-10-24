# ADR-0048 — Motore locale (LLM sul Mac)

- Stato: accettato
- Data: 2026-10-16
- Riferimenti spec: sez. 4.2, 5.2 (`LLMProvider`), 10, domanda aperta C; FR-110, FR-121, FR-219; ADR-0042 (integrato); richieste utente 2026-10-16

## Contesto
La Fase 3 si appoggia a un modello linguistico locale per:
- proposte automatiche di decisioni, attività ed entità (FR-110);
- chat con citazioni (FR-121);
- "Riordina testo" (FR-219);
- titoli proposti;
- più avanti, la ricerca per significato.

Richieste dell'utente:
- IAGO funziona anche **senza motore**: tutto ciò che non ne ha bisogno resta uguale;
- è l'utente a **scaricare e scegliere** il motore;
- senza motore le funzioni che ne hanno bisogno restano visibili e cliccabili, ma avvisano e aprono la scelta e il download;
- le funzioni "pesanti" (proposte automatiche, chat, ricerca per significato) non devono ripiegare su modelli di sistema di qualità incerta, perché minerebbe la credibilità dell'app;
- i **titoli proposti** per le decisioni nate da note e passaggi restano **sempre** ad Apple Intelligence (ADR-0042): il modello è già sul Mac, non richiede download e funziona bene per frasi brevi;
- "Riordina testo" solo con un motore locale presente e utilizzabile, mai con Apple Intelligence.

## Decisione

### 1. Motore dentro IAGO, con MLX (chiude la domanda aperta C)
- Il modello gira **nel processo di IAGO** con **MLX** di Apple (`mlx-swift` e la libreria LLM ufficiale di `ml-explore`, licenza MIT). La versione esatta si fissa in `Package.resolved` all'implementazione.
- **Niente Ollama e niente porta `localhost`.** Non serve un'app esterna e non c'è un servizio aperto sul Mac. La voce 2 della sez. 4.2 ("localhost verso LLM locale") resta inutilizzata.
- **Nuovo package `IAGOEngine`** (→ Core), in Swift puro e senza MLX:
  - protocollo `LLMProvider`: generazione di testo e di JSON vincolato a uno schema, annullabile;
  - catalogo dei modelli;
  - download e verifica;
  - scelta del motore attivo;
  - un provider finto per i test.
  Si testa con `swift test` e quindi gira nella CI come gli altri package. `IAGOIntelligence` vede solo il protocollo, ricevuto dall'app, senza dipendere da MLX.
- **Solo l'adattatore `MLXProvider`** importa MLX. È un target sottile dell'app, `IAGOEngineMLX`: carica il modello dalla cartella e genera. MLX compila shader Metal, che `swift test` non sa compilare, quindi l'adattatore si verifica con `xcodebuild`:
  - in locale, con `scripts/test-engine.sh`, prima di ogni PR che lo tocca;
  - nella CI, un job separato **solo manuale** (`workflow_dispatch`), da lanciare quando serve.
  Così la CI resta nei minuti gratuiti di GitHub Free: i runner macOS contano 10 volte e un build di MLX costerebbe circa 10 minuti, cioè circa 100 dei 2.000 minuti mensili, a ogni PR.
- **Telemetria:** nessuna chiamata di rete delle librerie. I modelli si caricano solo da una cartella locale. Il download dall'hub delle librerie non si usa e il controllo `check-network-apis.sh` lo verifica.

### 2. Catalogo curato, scelta dell'utente
- Solo modelli **affidabili e con licenza chiara**, delle famiglie **Qwen** (Alibaba, Apache 2.0) e **Gemma** (Google, Gemma Terms of Use), in versioni MLX quantizzate a 4 bit. Il catalogo iniziale ha 3 modelli, da circa 4B a circa 12B parametri; i nomi esatti si fissano all'implementazione, verificando che esistano.
- Per ogni modello il catalogo indica:
  - nome;
  - dimensione del download;
  - RAM consigliata;
  - lingue;
  - licenza;
  - URL fissi, al commit esatto del repository, con lo **SHA-256 di ogni file**.
- **Un solo motore attivo** alla volta, scelto dall'utente in **Impostazioni › Motore**. Lì si scarica, si annulla, si elimina e si sceglie "Usa questo".
- Prima del download, se la RAM del Mac è sotto quella consigliata, IAGO lo segnala e lascia comunque decidere all'utente.
- **Il modello predefinito si decide dopo una prova** di 2-3 modelli sulle call vere dell'utente: estrazione di decisioni e attività, titoli, riordino del testo, tempi.
  - La prova gira in locale con uno strumento di sviluppo.
  - I risultati vanno in `bench-out/`, mai nel repository.
  - Il predefinito è solo quello evidenziato nell'elenco: nessun download parte da solo.

### 3. Download
- **Solo su azione dell'utente**:
  - in background, con percentuale e velocità, nelle Impostazioni e nel menu della barra;
  - annullabile;
  - ripreso se interrotto, file per file;
  - ogni file verificato con SHA-256: se non corrisponde, il download viene scartato.
- Ogni download va nel **registro accessi** (`audit_log`, attore `model_download`): URL e dimensione.
- I file stanno in `Application Support/IAGO/Models/LLM/<modello>/`.
- **A download finito:** una notifica e, alla prima apertura, una scheda **"Il motore è pronto"** che presenta le funzioni ora disponibili, ciascuna con un pulsante per provarla.

### 4. Senza motore
- **Titoli proposti:** sempre Apple Intelligence, come oggi (ADR-0042), con o senza motore locale. Se Apple Intelligence non è disponibile resta la prima frase come suggerimento. Apple Intelligence si usa **solo per i titoli**.
- **Funzioni del motore** (proposte automatiche, chat, ricerca per significato, "Riordina testo"):
  - hanno un **segno comune** (icona del motore);
  - senza motore attivo, un clic apre **"Serve un motore locale"**: cosa farebbe la funzione, il fatto che tutto resta sul Mac, e i pulsanti **"Scegli e scarica un motore…"** (apre Impostazioni › Motore) e **"Non ora"**;
  - **non ripiegano** su Apple Intelligence o altri modelli di sistema.
- Ciò che non usa il motore resta com'è: registrazione e trascrizione delle call e delle note vocali (modelli di trascrizione propri), ricerca per parole, OCR, timeline, decisioni, MCP.

### 5. Funzioni che usano il motore
- **Blocco 3:** "Riordina testo" di una nota dettata o di un passaggio (FR-219), con anteprima e sostituzione solo se confermata. I titoli restano ad Apple Intelligence (ADR-0042).
- **Futuro:** riassunti per tipo di call, guidati dalla categoria (kickoff, 1to1, …), con lo stesso motore.
- **Blocchi 4-6:** proposte automatiche (FR-110), chat con citazioni (FR-121), ricerca per significato. Useranno lo stesso `LLMProvider` e lo stesso avviso.
- Il testo generato è sempre una **proposta**: si vede e si modifica prima di salvarlo, ed è segnato come proposto dal motore, con il nome del modello.

### 6. Prestazioni
- I lavori del motore sono `Job` in QoS `.utility`, uno alla volta. L'app resta reattiva e una registrazione in corso ha sempre la precedenza: i lavori lunghi aspettano la fine della call.
- Il modello si carica al primo uso e si scarica dalla memoria dopo 10 minuti di inattività.
- Nei log nessun testo: solo durata, modello e numero di token.

## Conseguenze
- IAGO resta utilizzabile a pieno anche senza motore. Il motore è un'aggiunta scelta e visibile, mai un ripiego nascosto.
- L'ADR-0042 resta valido così com'è: i titoli sono di Apple Intelligence; tutto il resto dell'intelligenza è del motore locale.
- Tutta la logica del motore è nella CI. Solo il sottile adattatore MLX si prova con `xcodebuild`: in locale prima della PR, nella CI solo a mano.
- Download di diversi GB, solo se l'utente li sceglie; lo spazio occupato compare in Impostazioni › Spazio.

## Modifica del 2026-10-21
- **Sintesi solo da 9B in su** (`EngineCatalog.minimumBillions`). Con un modello più piccolo il blocco Sintesi spiega che serve un motore più grande, e le sintesi automatiche non partono. Il 4B resta valido per proposte, Chiedi e riordino.
- **Modello consigliato:** Gemma 4 12B da 32 GB, **Qwen 3.5 9B da 16 GB** (prima era il 4B), Qwen 3.5 4B sotto i 16 GB.
- **Motivo:** nella prova su tre call reali il 4B teneva da 1 a 8 punti, il 9B 10-17, Gemma 10-31 (`docs/benchmarks/2026-10-21-sintesi-e-glossario.md`).
