# ADR-0039 — Note di progetto, allegati di progetto e note vocali

- Stato: accettato
- Data: 2026-10-13
- Riferimenti spec: FR-172…175, FR-210…218, sez. 7.7, 9.3

## Contesto
Le note di progetto non hanno un elemento. Gli allegati però erano legati per chiave esterna a `item`, e le chiavi di cifratura sono per elemento. Le note vocali devono essere trascritte subito senza conservare l'audio, e non devono mai perdersi.

## Decisione
- **Note di progetto:** `note.item_id` è nullo e `note.project_id` è valorizzato, come previsto dallo schema. Compaiono nella timeline del progetto alla loro data, insieme alle note degli elementi (FR-175).
- **Allegati di progetto (migrazione `v8-asset-owner`):**
  - `asset.item_id` diventa l'**id del proprietario**, cioè un elemento oppure un progetto, e perde la chiave esterna verso `item` (la tabella viene ricostruita).
  - Un progetto riceve una chiave in `item_key` al primo allegato, con la stessa cifratura per proprietario.
  - Eliminare il progetto distrugge i suoi allegati e la sua chiave (crypto-shredding).
- **Note vocali:**
  - **Registrazione:** solo microfono con `AVAudioEngine`, sull'input predefinito o sul microfono scelto nella barra dei menu. Il file va in `tmp/voice-notes/<uuid>.caf`, con accanto un JSON che indica la destinazione (elemento, progetto, nota) e la data. La cartella non viene svuotata all'avvio.
  - **Trascrizione:**
    - avviene subito, **fuori dalla coda dei lavori**: una sola traccia, nessuna diarizzazione, nessun filtro eco;
    - il motore è quello delle call e lavora un pezzo audio alla volta, quindi una nota si inserisce tra i pezzi di una trascrizione lunga, senza aspettarne la fine (FR-211);
    - si usa lo stesso motore scelto nelle impostazioni. L'impostazione separata "Motore note vocali" è rimandata finché il motore unico basta.
  - **Destino dell'audio:**
    - viene eliminato quando il testo è salvato nella nota, oppure se l'utente annulla;
    - se la trascrizione fallisce resta, con "Riprova / Scarta audio";
    - le registrazioni rimaste (fallite o interrotte da un crash) vengono riproposte all'avvio con "Trascrivi e salva / Più tardi / Scarta audio".
  - **Inserimento del testo:** nell'editor, "Aggiungi in coda" (predefinito) o "Sostituisci". La nota è marcata `input = voice`.
  - **"Nota vocale…" dalla barra dei menu:**
    - è un pannello che parte subito ad ascoltare;
    - la destinazione predefinita è l'ultimo elemento aperto o creato, oppure un altro elemento recente o un progetto;
    - la voce è disattivata durante una call;
    - se una call parte mentre si detta, la nota viene fermata e trascritta prima (FR-217).

## Conseguenze
- La pulizia del testo dettato con l'LLM locale (FR-219) arriverà nella Fase 3.
- Il backup cifrato (Blocco 6) deve includere le chiavi dei progetti presenti in `item_key`.
