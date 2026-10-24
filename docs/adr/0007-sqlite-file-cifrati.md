# ADR-0007 — SQLite (GRDB), file cifrati per riga, crypto-shredding

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 8, 9, 17.7

## Contesto
Servono un archivio locale affidabile con migrazioni e osservazione, cifratura dei contenuti e un'eliminazione davvero definitiva anche in presenza di copie residue (backup).

## Decisione
- SQLite tramite GRDB come archivio unico dei metadati (WAL, `PRAGMA secure_delete = ON`).
- File di ogni riga in `Items/<itemId>/`, cifrati con AES-GCM 256 (CryptoKit) con una chiave per riga, salvata in `item_key` cifrata dalla master key nel Portachiavi.
- "Elimina tutto" = eliminazione della chiave + file + dati testuali e indici. Senza chiave le copie residue sono illeggibili.
- Cartella IAGO esclusa da Time Machine per default.

## Conseguenze
- Riproduzione audio con decifratura in memoria o in `tmp/` (pulito a fine ascolto e all'avvio).
- Perdita della master key = perdita dei dati: in fase 2 "Esporta backup cifrato".
- Le registrazioni in corso in `tmp/sessions/` non sono cifrate fino alla finalizzazione.
