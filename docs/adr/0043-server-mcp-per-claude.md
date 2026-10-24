# ADR-0043 — Server MCP per Claude

- Stato: accettato
- Data: 2026-10-15
- Riferimenti spec: sez. 3.14 (FR-130…132), 12 (+ aggiornamento v1.4), 4.2; ADR-0010, ADR-0028, ADR-0038

## Contesto
La Fase 3 inizia dall'accesso di Claude all'archivio (spec 12). Secondo la spec il server legge "il DB in sola lettura". L'utente ha chiesto che Claude possa leggere anche i contenuti cifrati, cioè le trascrizioni complete con i nomi degli speaker aggiornati e il testo di documenti ed email, e non solo l'indice di ricerca. L'indice contiene già quei testi in chiaro, ma spezzati per frase e con i nomi degli speaker com'erano al momento dell'indicizzazione.

## Decisione
- **Eseguibile `iago-mcp`** dentro il bundle (`IAGO.app/Contents/MacOS/iago-mcp`):
  - firmato come l'app;
  - trasporto **stdio** (JSON-RPC 2.0, un messaggio per riga);
  - nessuna porta di rete. Il controllo automatico della rete vale anche per lui.
- **Lettura:**
  - **database:** connessione in sola lettura (`readonly`), senza migrazioni. WAL permette di leggere mentre l'app scrive;
  - **file cifrati:** il server legge la master key dal Portachiavi, come l'app (ADR-0028), e decifra in memoria solo quello che serve alla risposta. Non scrive mai file decifrati su disco;
  - **prima apertura:** macOS chiede una volta di consentire a `iago-mcp` l'accesso alla chiave di IAGO. Si risponde "Consenti sempre". Se l'utente nega, gli strumenti rispondono con un errore chiaro e non leggono niente.
- **Unica scrittura: il registro accessi.** Ogni chiamata aggiunge una riga a `audit_log` con:
  - attore `mcp`;
  - lo strumento usato;
  - i parametri, abbreviati;
  - il numero di elementi restituiti e i loro ID.
  Il contenuto restituito non viene mai registrato. La scrittura avviene su una connessione separata e breve, aperta solo per questo.
- **Confine:**
  - il server vede **solo** i progetti con "Consultabile da Claude" (`claude_accessible`, default spento);
  - gli elementi senza progetto, nel cestino o eliminati non sono mai visibili;
  - una decisione o nota è visibile solo se appartiene a un progetto abilitato.
- **Strumenti** (spec 12 v1.4). Accettano il progetto per ID o per nome e, dove serve, uno stream per nome:
  - `list_projects`;
  - `search`;
  - `get_item`;
  - `project_timeline`;
  - `list_decisions`;
  - `list_notes`;
  - `get_thread`;
  - `export_project`.
  Le descrizioni spiegano a Claude i tipi di elemento, le note dell'utente, gli stati delle decisioni e i possibili errori dell'OCR.
- **Formato delle risposte:** Markdown, con lo stesso formato dell'export per LLM (ADR-0041), in modo che Claude citi sempre titolo, data e minuto.
- **Impostazioni › Claude:**
  - l'interruttore per ogni progetto;
  - la configurazione da copiare per Claude Desktop e per Claude Code;
  - l'avviso: *i contenuti letti da Claude vengono inviati ai server di Anthropic*;
  - il registro degli accessi.

## Conseguenze
- Claude riceve contenuti completi e aggiornati, uguali all'export.
- La master key è letta da un secondo processo firmato dallo stesso team. Il rischio è limitato, perché il server gira solo quando Claude lo avvia e vede solo i progetti abilitati.
- Le chiamate di rete restano invariate: l'invio ad Anthropic lo fa Claude Desktop, con l'abbonamento dell'utente, e IAGO lo dichiara nell'avviso.
- La spec diceva "DB in sola lettura": la deviazione riguarda la sola lettura della chiave e l'inserimento nel registro accessi.

## Aggiornamento 2026-10-15: connessioni per ambito
- **Una connessione per ambito.** L'utente può creare più connessioni, scegliendole da un elenco in Impostazioni › Claude o nelle Impostazioni di un progetto o cliente:
  - **tutti i progetti consultabili:** `iago`;
  - **un cliente:** `iago-<cliente>`, avviata con `--client ID`;
  - **un progetto:** `iago-<progetto>`, avviata con `--project ID`. Con un solo progetto, Claude non deve indicarlo negli strumenti;
  - **tutti i progetti più gli elementi "Da classificare":** `iago-tutto`, avviata con `--unclassified`. Il progetto virtuale si chiama "Da classificare".
- **Deroga a FR-131.** La spec diceva che le righe senza progetto non sono mai consultabili. Ora lo diventano, ma solo in una connessione creata esplicitamente dall'utente, con un avviso in arancione. Le altre connessioni continuano a escluderle.
- **Confine invariato:** in ogni ambito valgono solo i progetti con "Consultabile da Claude", e il cestino resta escluso.
- **Togliere una connessione:** Impostazioni › Claude elenca quelle già presenti in Claude Desktop, con "Togli". Prima di ogni modifica IAGO salva una copia del file di configurazione (`.bak-iago`).

## Aggiornamento 2026-10-15: copia della chiave per il collegamento
- **Il problema.** Avviato da Claude Desktop, il server non può mostrare la richiesta di accesso del Portachiavi e fallisce con l'errore -25320 (`errSecInteractionNotAllowed`).
- **La scelta dell'utente (opzione A):**
  - all'avvio di IAGO, e quando un progetto diventa consultabile, l'app passa la master key a `iago-mcp --provision` attraverso una pipe, mai tramite file o riga di comando;
  - il server la salva come voce sua nel Portachiavi (servizio `com.giovannilombi.iago.mcp`, account `master-key-copy`), che può poi leggere senza richieste.
- **Lettura della chiave:**
  - il server usa prima la propria copia, e solo in mancanza di questa la voce dell'app;
  - non crea mai una chiave nuova.
- **Conseguenza:** nel Portachiavi di login ci sono due copie della master key, entrambe su questo Mac e non sincronizzate. Se nessun progetto è consultabile, la copia non viene creata.
