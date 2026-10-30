# ADR-0080 — Condividere un elemento

- Stato: accettato (1.2.7-beta)
- Data: 2026-10-30
- Riferimenti: ADR-0058 (niente esce senza la scelta dell'utente), ADR-0073 (impronte delle voci), ADR-0078 (due trascrizioni); richiesta dell'utente del 2026-10-30

## Contesto
- Mandare una call, un'email o un documento a chi non usa IAGO voleva dire esportare file uno alla volta dalla sezione *File*, o copiare testi a mano.
- L'idea «inviare attività ad altri» (lavoro aperto) è diventata più ampia: condividere l'elemento con quello che serve, scegliendo le parti.

## Decisione
- *Condividi…* tra le azioni della scheda apre un elenco delle parti che l'elemento ha, con la dimensione, da spuntare:
  - **Scheda (Markdown):** data, progetto, categoria, durata, partecipanti, tag, sintesi, punti chiave con il loro stato, note. Senza trascrizione;
  - **Trascrizione** principale con i nomi degli speaker, o il testo di email e documenti; l'**altra trascrizione** se la call ne ha due;
  - **Audio** (mix o file importato) e **tracce separate** (microfono e sistema);
  - **Originale:** `.eml`, documento, immagine o trascrizione di Teams;
  - **Schermate**, con il minuto nel nome.
- IAGO decifra le parti in una cartella temporanea (`IAGO-Condividi`, svuotata alla condivisione successiva), facoltativamente in un solo `.zip` fatto con `ditto` di macOS, e poi:
  - *Condividi…* apre il menu Condividi di macOS (Mail, Messaggi, AirDrop, altre app);
  - *Salva in una cartella…* le copia dove sceglie l'utente.
- **Nessuna chiamata di rete da IAGO:** i file escono solo attraverso l'app scelta dall'utente.
- Le impronte delle voci non sono asset e non sono mai tra le parti (ADR-0073).
- La finestra avvisa che i file condivisi non sono cifrati. Ogni condivisione va nel registro accessi (`export/share`) e compare in Attività mentre si preparano i file.

## Conseguenze
- Sostituisce l'idea «inviare attività ad altri prima della fase 4».
- I testi dei file (titoli delle sezioni) seguono quelli delle esportazioni esistenti.
