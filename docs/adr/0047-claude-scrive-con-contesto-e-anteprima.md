# ADR-0047 — Claude scrive con contesto e anteprima

- Stato: accettato
- Data: 2026-10-16
- Riferimenti spec: sez. 12; ADR-0043, ADR-0044, ADR-0046; richiesta utente 2026-10-16

## Contesto
Con l'ADR-0044 Claude scrive in IAGO esattamente ciò che gli si chiede, dove gli si chiede. Nella prima prova vera:
- una decisione aggiunta da Claude ha preso la data dell'email da cui nasceva, arrotondata al minuto, ed è finita in fondo alla giornata del giorno prima, sotto gli allegati: l'utente non l'ha vista;
- Claude non sa distinguere una nota da una decisione, non guarda le decisioni esistenti per proporre di superarle e non conosce gli stream.

L'utente chiede che Claude capisca il contesto, chieda quando c'è un dubbio e che tutto ciò che scrive finisca nel posto giusto. La coerenza dell'archivio va garantita da IAGO stesso, non solo dalla buona volontà di Claude.

## Decisione

### 1. Anteprima obbligatoria
- Ogni strumento di scrittura funziona in due passi.
  1. **Senza `confirmation`**, non scrive nulla e restituisce un'**anteprima**:
     - cosa verrà scritto e di che tipo;
     - progetto e stream;
     - a cosa è collegato e quale voce supera;
     - data, e **dove comparirà in timeline** ("in cima", oppure "il 15 ott, accanto a «…»");
     - i **dubbi** rilevati da IAGO (sez. 3);
     - un codice di conferma.
  2. **Con `confirmation` uguale a quel codice e gli stessi parametri**, scrive.
- Il codice è legato ai parametri: se Claude cambia qualcosa dopo l'anteprima, serve una nuova anteprima. Scade dopo 15 minuti.
- Le istruzioni chiedono a Claude di mostrare l'anteprima all'utente e di confermare solo dopo il suo OK.
  - Il server non può verificare che l'utente l'abbia vista: questo resta affidato a Claude e ai permessi del client.
  - Il server garantisce però che nessuna scrittura avvenga senza un'anteprima calcolata sugli stessi parametri.

### 2. Date
- **Default: adesso.** Una voce aggiunta da Claude compare in cima alla timeline.
- Una data diversa solo se l'utente la indica. Claude la passa in `date`, oppure con `date: "source"` prende la **data esatta della fonte**: l'orario dell'elemento, più `at_sec` per una call.
- Se la data è nel passato, l'anteprima lo segnala con la posizione in timeline, così Claude la fa confermare.

### 3. Controlli di IAGO
L'anteprima segnala come dubbi:
- **decisioni attive simili** nello stesso progetto (o stream), quando non è indicato `supersedes_id`, perché Claude chieda se vanno superate. Somiglianza per parole in comune, senza modelli;
- una data **precedente** alla voce che si supera;
- un `supersedes_id` che **viene già dopo** nella catena. Lo stesso caso gestito nell'app: con conferma si cambia l'ordine della catena;
- uno stream che non esiste nel progetto. È un errore, non un dubbio: Claude riceve l'elenco degli stream validi.

### 4. Stream e collegamenti
- `add_note`, `add_decision` e `create_document` accettano `stream`: il nome di uno stream del progetto.
- Le note oggi non hanno stream.
  - Nuova tabella `note_stream` (migrazione `v12-note-stream`).
  - Una nota in uno stream compare nella timeline di quello stream.
  - La finestra della nota permette di scegliere lo stream anche a mano.
- `add_note` con `item_id` si collega a qualsiasi elemento: call, email, documento, file.
- `add_decision` accetta `source_item_id`, qualunque elemento, e `source_note_id`, la nota da cui nasce.
- `create_document` accetta `related_item_ids`: collegamenti `item_link` con origine `mcp`.
- `update_decision` accetta `supersedes_id`, con gli stessi controlli dell'anteprima.

### 5. Trovare le decisioni
- `list_decisions` accetta `query`: parole del testo o della descrizione.
- Serve per "è cambiata la decisione sul contributo": Claude trova le candidate e, se sono più d'una o nessuna, chiede.

### 6. Istruzioni di lavoro
Le istruzioni inviate da IAGO alla connessione diventano un manuale di lavoro:
- **leggere prima di scrivere:** decisioni attive, stream, note e timeline recente del progetto;
- **scegliere il tipo:**
  - nota: un'informazione da ricordare;
  - decisione: qualcosa di deciso che vale finché non è superato;
  - attività: qualcosa da fare;
  - tappa: un fatto avvenuto;
- **chiedere invece di indovinare:** tipo, stream, decisione da superare, data, collegamento;
- **seguire il flusso anteprima, OK dell'utente, conferma**, e riferire dove è finita la voce.

### 7. Marcatura degli strumenti
Gli strumenti hanno le annotazioni MCP standard e un titolo in italiano:
- **lettura:** `readOnlyHint: true`;
- **scrittura:** `readOnlyHint: false`, `destructiveHint: false` (tutto è annullabile da IAGO), `idempotentHint: false`;
- **tutti:** `openWorldHint: false`.

### 8. Permessi nei client
I permessi li concede il client: IAGO non può darsene da sé. In Impostazioni › Claude:
- **Claude Code:** un pulsante "Consenti tutti gli strumenti in Claude Code". Aggiunge `mcp__<connessione>` a `permissions.allow` in `~/.claude/settings.json`, dopo una conferma e solo in quella voce del file;
- **Claude Desktop:** un riquadro "Evitare le richieste di permesso" con i passi nelle impostazioni dei connettori. Avvisa che dopo un aggiornamento di Claude Desktop può servire ripeterli e che negli account aziendali dipende dall'amministratore.

## Conseguenze
- Ogni scrittura costa un passo in più, l'anteprima, ma nulla entra in IAGO senza che data, posizione, collegamenti e catena siano stati mostrati.
- Le voci di Claude, di default, sono le più recenti della timeline.
- La migrazione `v12-note-stream` porta gli stream anche alle note, nell'app oltre che in Claude.
- Sostituisce, per gli strumenti di scrittura, il flusso a un passo dell'ADR-0044. Provenienza, annullamento e permessi per progetto restano come nell'ADR-0044.
