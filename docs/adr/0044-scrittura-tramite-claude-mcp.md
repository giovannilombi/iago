# ADR-0044 — Scrittura tramite Claude (MCP)

- Stato: accettato
- Data: 2026-10-15
- Riferimenti spec: sez. 12, 3.14; ADR-0043; richiesta utente 2026-10-15

## Contesto
Con il collegamento MCP (ADR-0043) Claude legge i progetti abilitati. L'utente vuole poter usare Claude anche per scrivere in IAGO: aggiungere e modificare note e decisioni, creare documenti, inserire elementi. Trascrizioni, audio e file originali devono restare non modificabili. Quello che entra da Claude deve essere riconoscibile come **inserito dall'utente tramite Claude (MCP)**, non come lavoro autonomo di un'intelligenza artificiale.

## Decisione
- **Permesso separato per progetto: "Claude può anche scrivere".**
  - È una nuova colonna, `project.claude_writable`, spenta di default (migrazione `v11-mcp-write`).
  - Vale solo se il progetto è anche consultabile e rientra nell'ambito della connessione.
  - Gli elementi senza progetto non si possono scrivere da Claude.
- **Strumenti di scrittura:**
  - `add_note`: nota di progetto o su un elemento;
  - `update_note`;
  - `add_decision`: con descrizione, data, fonte, "supera", persone e tag;
  - `update_decision`: testo, descrizione, stato attiva/annullata, nome della catena;
  - `create_document`: documento Markdown;
  - `add_email`: email inserita a mano, con mittente, destinatari, data e direzione.
  Nessuno strumento tocca trascrizioni, audio, originali o il testo estratto dei documenti importati.
- **Provenienza:**
  - le note hanno `input = mcp`, le decisioni `origin = mcp`, gli elementi `source = mcp`;
  - le modifiche finiscono nella tabella `mcp_change`;
  - l'interfaccia mostra **"Inserita tramite Claude (MCP)"** o **"Modificata tramite Claude (MCP)"**, con il segno di Claude.
- **Annullare:**
  - `mcp_change` conserva per ogni scrittura il tipo di oggetto, l'ID e, per le modifiche, i valori precedenti (in JSON nel database, che già contiene in chiaro i testi di note e decisioni, spec 9.3);
  - in Impostazioni › Claude, "Modifiche tramite Claude (MCP)" elenca le scritture con **Annulla**:
    - una creazione annullata viene eliminata: un elemento va nel cestino, una decisione eliminata riattiva quella che aveva superato;
    - una modifica annullata torna ai valori precedenti.
- **Processo:**
  - il server legge sempre dalla connessione in sola lettura (ADR-0043);
  - una connessione in scrittura, senza migrazioni, si apre solo alla prima chiamata di uno strumento di scrittura;
  - IAGO, se è aperto, si accorge delle modifiche di un altro processo controllando `PRAGMA data_version` ogni 2 secondi e ricarica.
- **Registro:** ogni scrittura va in `audit_log` come le letture: strumento, parametri abbreviati, ID. Mai il contenuto.

## Conseguenze
- Claude diventa uno strumento per inserire e sistemare informazioni in IAGO, sempre su richiesta dell'utente, sempre riconoscibile e annullabile.
- Il server MCP scrive nel database; la protezione è il doppio permesso per progetto, consultabile e scrivibile.
- I documenti creati da Claude sono elementi `document` con il Markdown come originale e come testo, cifrati come gli altri.
