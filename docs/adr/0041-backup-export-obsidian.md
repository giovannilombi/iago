# ADR-0041 — Backup cifrato, trasferimento su un nuovo Mac, export e specchio Obsidian

- Stato: accettato
- Data: 2026-10-13
- Riferimenti spec: sez. 9.3, 10.4, 11.2, 11.3; FR-90, FR-91, FR-122, FR-191; ADR-0028; richieste utente (export audio, nuovo Mac)

## Contesto
L'archivio è cifrato con una master key nel Portachiavi (ADR-0028). Perdere il Mac o la chiave renderebbe illeggibile tutto. L'utente vuole anche condividere audio, passare a un nuovo Mac con un archivio identico, dare un progetto a un LLM e vederlo in Obsidian.

## Decisione
- **Backup cifrato** (`IAGOStore/Backup.swift`):
  - **Formato:** un file `.iagobackup` in **Apple Encrypted Archive**, formato di sistema senza dipendenze esterne, con profilo scrypt + AES-CTR + HMAC e compressione LZFSE.
  - **Contenuto:** una copia coerente del database (backup SQLite, valido anche mentre l'app scrive), la cartella `Items` con i file già cifrati per elemento (clonati su APFS, quindi senza spazio doppio), la master key e un manifest.
  - **Password:** scelta dall'utente, di almeno 10 caratteri. Apple Archive accetta solo password molto lunghe, quindi quella dell'utente viene allungata con PBKDF2-SHA256 (600.000 iterazioni) prima di passare a scrypt con il sale casuale dell'archivio.
  - **Recupero:** IAGO non conserva la password e nessuno può recuperarla; l'interfaccia lo dice.
- **Ripristino:**
  - il file viene decifrato e verificato subito (manifest, chiave, database apribile con le migrazioni correnti) in `restore-pending`;
  - lo scambio avviene al riavvio, prima di aprire il database;
  - l'archivio precedente **non viene cancellato**: va in `Archivi sostituiti/<data>`, e la sua chiave resta nel Portachiavi come `master-key-before-restore-<data>`;
  - "Ripristina un backup" è disponibile anche nella prima schermata dell'onboarding, per il nuovo Mac.
- **Export per LLM** (`ProjectExporter`): un unico file Markdown per la vista attuale (progetto, cliente, stream, filtri) secondo spec 11.2/11.3:
  - indice, poi registro decisioni con stato, fonte e catena "supera";
  - poi elementi e note di progetto in ordine cronologico, con l'intestazione per tipo;
  - documenti interi o come estratto;
  - stima dei token (circa un token ogni 3,6 caratteri).
- **Export audio:** copie `.m4a` non cifrate, opzionalmente con la trascrizione `.md`, per la vista attuale o per tutto l'archivio.
- **Specchio Obsidian** (`ObsidianMirror`):
  - solo da IAGO verso il vault, solo per i progetti abilitati (con avviso che sono in chiaro), nella sottocartella `IAGO/`;
  - un file per ogni elemento, nota di progetto e decisione, più note per progetto, cliente e persona, con i wikilink;
  - IAGO riscrive o rimuove **solo** i file con `iago_id` nel front matter, e un file dell'utente con lo stesso nome non viene toccato;
  - l'aggiornamento parte 10 secondi dopo l'ultima modifica.
- **Markdown correggibile** (FR-191): la prima correzione conserva il testo estratto come `content_md_auto`; "Ripristina il testo automatico" lo rimette. La ricerca segue il testo corretto.
- **Audit:** ogni export, impostazione di Obsidian, backup e ripristino viene annotato nel registro (`export`, `backup`), mai con il contenuto.

## Conseguenze
- Nessuna rete: il controllo automatico delle API di rete resta verde.
- Un backup contiene la master key: la sua sicurezza dipende dalla password, che l'interfaccia chiede di custodire.
- Gli archivi in `Archivi sostituiti` si eliminano da Impostazioni › Backup e trasferimento, con la stessa tripla conferma dei progetti (avviso, scrivere DELETE, ultima conferma). L'eliminazione distrugge la cartella e la sua chiave nel Portachiavi, e viene annotata nel registro.
