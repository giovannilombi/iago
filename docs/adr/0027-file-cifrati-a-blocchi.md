# ADR-0027 — File cifrati a blocchi AES-GCM

- Stato: accettato
- Data: 2026-10-12
- Riferimenti spec: sez. 9.1, 9.2, 9.4; ADR-0007

## Contesto
La spec chiede file cifrati per elemento con AES-GCM (CryptoKit). Una call di un'ora produce decine di MB di audio: un unico `AES.GCM.seal` richiederebbe di tenere tutto in memoria, sia in cifratura sia in lettura. Serve anche rilevare file troncati, riordinati o scambiati tra loro.

## Decisione
- Formato `IAGOENC` versione 1: intestazione (`IAGOENC`, versione, dimensione del blocco) seguita da blocchi da 1 MB, ognuno `nonce (12) | testo cifrato | tag (16)`, con nonce casuale per blocco.
- I dati autenticati di ogni blocco comprendono intestazione, un **contesto** (il percorso relativo, es. `<itemId>/mic.m4a.enc`), l'indice del blocco e il flag "ultimo blocco". Scambiare file tra loro, riordinare o rimuovere blocchi, troncare a un confine di blocco o aggiungere dati fa fallire la decifratura.
- Un file vuoto è un solo blocco vuoto marcato come ultimo.
- Cifratura e decifratura in streaming, con scrittura su file temporaneo e spostamento atomico al termine: un errore non lascia mai file parziali.
- La chiave è quella dell'elemento (ADR-0028). Lo SHA-256 registrato in `asset.sha256` è quello del **contenuto in chiaro**, ricalcolato a ogni lettura (FR-54).
- I file si chiamano `<nome originale>.enc` in `Items/<itemId>/`.

## Conseguenze
- Memoria costante (circa 1 MB) per file di qualsiasi durata.
- Overhead di 28 byte per MB, trascurabile.
- Per la riproduzione l'audio si decifra in `tmp/playback/`, ripulita a fine ascolto e all'avvio (sez. 9.4).
- Un cambio di formato richiede una nuova versione nell'intestazione e la lettura delle versioni precedenti.
