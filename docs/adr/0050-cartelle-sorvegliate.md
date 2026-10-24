# ADR-0050 — Cartelle sorvegliate per le email

- Stato: accettato
- Data: 2026-10-19
- Riferimenti spec: sez. 7.x (import email, FR-180…184), ADR-0040 (parser email); richiesta utente 2026-10-19

## Contesto
Le email entrano in IAGO solo se l'utente le trascina o le importa. Intercettarle direttamente da Outlook richiederebbe l'IT o la rete (Microsoft Graph, componenti aggiuntivi) oppure la lettura fragile della cache di Outlook. L'utente può però creare da solo una regola di **Power Automate** che salva le email come `.eml` in una cartella di OneDrive sincronizzata sul Mac. Serve che IAGO:
- sorvegli quella cartella;
- importi solo il nuovo, a delta;
- scarti da solo quello che non serve, come gli inviti ai meeting;
- assegni il progetto in blocco, con meno conferme possibili.

## Decisione
- **Cartelle sorvegliate** (Impostazioni › Email e persone):
  - una o più cartelle, con le sottocartelle;
  - file `.eml` ed `.emlx`;
  - IAGO le guarda quando cambiano e comunque ogni minuto, perché OneDrive non sempre segnala i file nuovi.
  - Per ogni cartella: attiva o in pausa, e "Sposta le importate nella sottocartella «Importate»", spento di default.
  - Niente rete: IAGO legge file locali. Power Automate è dell'utente e gira sul suo account.
- **Delta:**
  - un registro (`watched_file`, migrazione `v15-watched-folders`) tiene percorso, dimensione, data di modifica, SHA-256, esito ed elemento creato;
  - un file già visto e non cambiato non si riapre;
  - lo stesso contenuto in un altro percorso è un doppione;
  - la stessa email (stesso Message-ID) già in archivio è un doppione, come oggi;
  - l'esito di ogni file è uno tra **importata**, **doppione**, **scartata** (con il motivo) e **non riuscita** (con l'errore).
- **Regole:**
  - **di serie, attive:**
    - inviti e risposte ai meeting: contenuto `text/calendar`, oppure oggetti "Accettato:", "Rifiutato:", "Provvisorio:", "Annullato:", "Invito:", "Accepted:", "Declined:", "Tentative:", "Canceled:", "Invitation:";
    - risposte automatiche: intestazione `Auto-Submitted`, `X-Autoreply`, oppure oggetti "Risposta automatica", "Automatic reply", "Fuori sede", "Out of office";
  - **di serie, spenta:** newsletter, riconosciute dall'intestazione `List-Unsubscribe` o da `Precedence: bulk/list`;
  - **dell'utente**, in ordine:
    - "**Escludi** se mittente / dominio / destinatario / oggetto contiene…";
    - "**Assegna a** progetto (e stream) se mittente / dominio / destinatario / oggetto contiene…".
  - **Ordine di applicazione:** prima le esclusioni, poi le assegnazioni. Senza una regola che assegna vale la proposta che IAGO già fa per le email: thread, indirizzi già visti, progetto del mittente. Se la proposta non è certa, l'email entra in "Da classificare".
- **In blocco:**
  - nessuna finestra per singola email;
  - alla fine una notifica riassuntiva: "Importate 12 email (3 scartate, 2 doppioni)";
  - gli allegati seguono la scelta di oggi: tutti tranne le immagini sotto i 20 KB, cioè firme e loghi;
  - l'elenco **"Scartate"** permette **"Importa comunque"**.
- **Le regole stanno in IAGOIngest** come funzione pura, testata senza archivio. Le regole salvate e il registro dei file stanno in IAGOStore (`import_rule`, `watched_folder`, `watched_file`).

## Conseguenze
- Con una regola di Power Automate, le email in entrata e in uscita arrivano in IAGO senza IT e senza aprire la rete.
- Le regole servono anche a scartare il rumore. Gli scarti restano visibili e recuperabili.
- Un formato diverso da `.eml`/`.emlx`, per esempio `.msg` di Outlook per Windows, non è supportato: Power Automate salva in `.eml`.
