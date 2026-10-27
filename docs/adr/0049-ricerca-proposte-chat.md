# ADR-0049 — Ricerca per significato, proposte automatiche e chat

- Stato: accettato
- Data: 2026-10-19
- Riferimenti spec: sez. 10 (10.1-10.3 e aggiornamento v1.4), 8 (`suggestion`, `chunk`), 6.x (Condividi/Servizi); FR-101, FR-110, FR-111, FR-121, FR-150 (punto 4), FR-201, FR-205; ADR-0048; richiesta utente 2026-10-19 (Blocchi 4, 5 e 6 insieme)

## Contesto
Con il motore locale (ADR-0048) restano tre funzioni della Fase 3:
- **ricerca per significato** (Blocco 4);
- **proposte automatiche** di decisioni, attività, persone, tag e collegamenti (Blocco 5);
- **chat con citazioni** e il menu **Condividi/Servizi** "Aggiungi a IAGO" (Blocco 6).

Valgono le stesse regole del motore:
- tutto resta sul Mac;
- senza motore IAGO funziona come oggi;
- le funzioni avvisano e propongono il download;
- nessun ripiego su Apple Intelligence;
- i Mac da 16 GB, la maggioranza degli utenti, devono reggere tutto con Qwen 3.5 4B.

## Decisione

### 1. Ricerca per significato (Blocco 4)
- **Modello di embedding:** Qwen3 Embedding 0.6B in MLX 4 bit (`mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ`, Apache 2.0, circa 350 MB). È multilingue e supportato da `MLXEmbedders`, la stessa libreria del motore.
  - È nel catalogo con commit fissato e SHA-256 di ogni file, come gli altri modelli.
  - **Si scarica insieme al primo motore**: l'utente fa una sola scelta, e la riga del motore indica "+ 0,35 GB per la ricerca".
  - Si può anche scaricare da solo, in Impostazioni › Motore.
- **Pezzi (chunk):** come la spec 10.1.
  - Le call si dividono per turni di parola, in pezzi di 200-400 parole con un turno di sovrapposizione, con minuto d'inizio e di fine e speaker.
  - Email, documenti e note si dividono per paragrafi.
  - Tabella `chunk` (migrazione `v13-intelligence`) con il vettore in un `BLOB` di `float32` normalizzati, più il modello che l'ha calcolato. Se il modello cambia, un job ricalcola tutto.
- **Niente `sqlite-vec`:** il confronto è un prodotto scalare in Swift con Accelerate su tutti i vettori dell'ambito, cioè progetto, cliente o tutto l'archivio.
  - Con 10.000 pezzi si tratta di circa 40 MB e qualche millisecondo.
  - Non aggiunge una dipendenza in C né un'estensione SQLite da firmare.
  - Se servisse più velocità si potrà cambiare dietro la stessa interfaccia.
- **Ricerca ibrida** (spec 10.2):
  - le parole (FTS5, BM25) e il significato (coseno) si fondono con Reciprocal Rank Fusion;
  - i filtri si applicano prima della fusione;
  - senza modello di embedding resta la ricerca per parole di oggi, con una riga che spiega cosa si aggiungerebbe.
- **Indicizzazione in background:** job in QoS `.utility`, uno alla volta, dopo ogni trascrizione o importazione, più un job iniziale su tutto l'archivio con avanzamento nella barra dei menu. Durante una registrazione i job aspettano.
- **MCP:** per ora `search` resta per parole. Il server MCP non carica modelli; i vettori sono già nel database, ma serve il modello per la domanda. Si valuterà dopo.

### 2. Proposte automatiche (Blocco 5)
- **Quando:** dopo la trascrizione di una call e dopo l'importazione di un'email o di un documento (FR-205), come job in background.
  - L'impostazione "Proponi automaticamente" in Impostazioni › Motore è attiva di default quando c'è un motore.
  - Si può anche lanciare a mano: "Cerca proposte" nella scheda dell'elemento.
- **Cosa propone:**
  - **decisioni e attività**, con `KeyPointExtractor`: definizioni rigide, blocchi di 10 minuti, citazione verificata e severa sui numeri, sicurezza, massimo 12 per elemento;
  - **"supera"**: se una decisione proposta somiglia a una decisione attiva del progetto, la proposta lo dice ("Potrebbe superare «…»") e la conferma la collega;
  - **persone**: speaker con nome, mittenti e destinatari delle email, nomi citati e verificati nel testo, con unione a una persona esistente (FR-111);
  - **tag**: solo tra i tag che già esistono, per non inventarne di nuovi; più al massimo 3 tag nuovi, segnati come tali;
  - **progetto** per gli elementi "Da classificare": scelto tra i progetti esistenti, con il motivo;
  - **collegamenti** (FR-201): gli elementi più vicini per significato nello stesso progetto, sopra una soglia, come `related`.
- **Dove si vedono:**
  - nella scheda dell'elemento, la sezione **"Proposte (N)"** con **Conferma**, **Modifica…** e **Scarta**, e la citazione con il minuto cliccabile;
  - nella timeline, un segno sulla scheda dell'elemento;
  - in Punti chiave, il filtro **"Da confermare"**;
  - a fine job, una notifica: "3 proposte da controllare in «…»".
- **Mai applicate senza conferma.** Una proposta confermata diventa una normale decisione, attività, persona, tag o collegamento, con origine `extraction` e il nome del modello. Una proposta scartata non torna a ogni nuova estrazione dello stesso elemento.
- **Tabella `suggestion`** (spec 8; migrazione `v13-intelligence`):
  - `id`, `item_id`, `kind` (`decision`, `activity`, `person`, `tag`, `project`, `link`);
  - `payload` JSON (testo, citazione, minuto, sicurezza, destinatario dell'eventuale "supera");
  - `status` (`pending`, `accepted`, `rejected`, `merged`);
  - `model`, `created_at`.

### 3. Chat con citazioni (Blocco 6)
- **Dove:** un pannello **"Chiedi"** nella finestra principale, sull'ambito selezionato (progetto, cliente, tutto). Si apre con ⌘K o con il pulsante nella barra.
- **Come risponde:**
  - recupera con la ricerca ibrida i pezzi più pertinenti dell'ambito, circa 12 con il modello piccolo, e li dà al motore etichettati per tipo e data, come nella spec 10.3 v1.4: note come "Nota dell'utente del…", email con direzione, documenti con l'avviso sull'OCR;
  - le istruzioni dicono che prevale l'informazione più recente, che i conflitti vanno segnalati e che per "cosa vale oggi" valgono solo le decisioni attive;
  - ogni affermazione ha un rimando **[1] [2]** cliccabile all'elemento e al minuto;
  - una risposta senza fonti dice "Non trovo nulla nell'archivio su questo".
  - Con Qwen 3.5 4B le risposte sono brevi e per punti, e il pannello ricorda che vanno verificate sulle fonti.
- **Conversazioni** (modifica del 2026-10-19, su richiesta dell'utente):
  - si salvano nelle tabelle `conversation` e `conversation_turn` (migrazione `v14-conversations`), con ambito, domande, risposte, fonti citate e il nome del modello;
  - sono **temporanee per 48 ore** dall'ultima domanda. In cima compare "Conversazione temporanea: si cancella il… · **Conserva**". Si possono **fissare in alto**, e una conversazione fissata è anche conservata;
  - l'elenco "Conversazioni" è nel pannello: prima le fissate, poi le più recenti. La cancellazione automatica avviene all'avvio e poi ogni minuto, insieme ai lavori in background;
  - riaprendo una conversazione, se nell'ambito c'è **materiale aggiunto o modificato dopo l'ultima risposta** compare "Nuovo materiale aggiunto: la risposta potrebbe essere parziale", con **"Chiedi di nuovo"**. Con il modello di ricerca l'avviso conta solo il materiale che riguarda la domanda; senza, conta tutto per data. Costa una sola interrogazione, più una ricerca se c'è il modello;
  - una fonte eliminata compare come "non più disponibile";
  - "Salva come nota" porta una risposta nelle note del progetto.
- **Senza motore:** il pannello si apre e spiega "Serve un motore locale". Senza modello di embedding la chat usa la ricerca per parole, con meno precisione, e lo dice.

### 4. Condividi / Servizi (Blocco 6)
- **Servizio di macOS "Aggiungi a IAGO"**: testo selezionato in qualsiasi app, tasto destro › Servizi. Il testo arriva nell'importazione di IAGO come testo incollato, con la scelta del progetto. Si dichiara con `NSServices` nell'Info.plist, senza estensioni separate né permessi in più.
- **Il menu Condividi** dei file (Finder, Mail) richiede un'estensione Share separata, firmata, con un App Group. Si rimanda alla distribuzione e intanto restano il trascinamento e "Importa".

### 5. Prestazioni sui Mac da 16 GB
- Motore ed embedding non lavorano mai insieme: i job vanno in coda e ne gira uno alla volta.
- Durante una registrazione nessun job del motore parte; quelli in corso finiscono il pezzo attuale e si fermano.
- Il modello lascia la memoria dopo 10 minuti di inattività (ADR-0048). Se macOS segnala poca memoria, il job si sospende e riprende dopo.
- La chat ha la precedenza sui job: se l'utente fa una domanda, il job in corso aspetta.

## Conseguenze
- Nuove migrazioni `v13-intelligence` (`chunk`, `suggestion`) e `v14-conversations`, con backup prima dell'aggiornamento come per la `v12`.
- Un modello in più da scaricare, piccolo e legato al primo motore.
- `IAGOIntelligence` ospita chunking, ricerca ibrida, estrazione e contesto della chat, testati con un motore finto. La parte MLX resta nell'app (`App/Sources/Engine`).
- Il menu Condividi completo è rimandato alla distribuzione, perché richiede un'estensione firmata.

## Modifica del 2026-10-27 (ADR-0069)
- "Motore ed embedding uno alla volta", "la chat ha la precedenza" e "con poca memoria il job si sospende" sono implementati dalla **coda unica** di ADR-0069: la chat interrompe il blocco in corso, che poi si rifà.
- **"Proponi automaticamente"** è acceso di default solo sui Mac da 32 GB in su; sotto, le proposte partono da «Cerca proposte», e l'utente può riaccenderlo.
