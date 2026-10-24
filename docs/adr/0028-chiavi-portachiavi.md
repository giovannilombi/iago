# ADR-0028 — Master key nel Portachiavi e chiavi per elemento

- Stato: accettato
- Data: 2026-10-12
- Riferimenti spec: sez. 9.2, 9.3, 16.3

## Contesto
La spec prevede una master key nel Portachiavi e una chiave per elemento cifrata con la master key, così che eliminare la chiave di un elemento lo renda illeggibile (crypto-shredding). Con il Personal Team gratuito il Portachiavi "data protection", che serve per i gruppi di accesso condivisi, richiede entitlement che vanno verificati: servirà solo in fase 3 per `iago-mcp`.

## Decisione
- **Master key**: AES-256 casuale, creata al primo avvio, salvata come password generica nel Portachiavi di login (servizio `com.giovannilombi.iago`, account `master-key`), **non sincronizzabile** con iCloud. macOS la lascia leggere senza richieste solo all'app che l'ha creata (stessa firma).
- **Chiave per elemento**: AES-256 casuale, salvata in `item_key.wrapped_key` sigillata con AES-GCM dalla master key, con l'ID dell'elemento come dato autenticato (una chiave non può essere spostata su un altro elemento).
- **Eliminazione definitiva**: si cancella prima la riga `item_key`, poi i file, poi i testi nel DB. Copie residue dei file (backup) restano illeggibili.
- Il Portachiavi sta dietro il protocollo `MasterKeyStore`: i test usano una chiave in memoria.

## Conseguenze
- Cambiare firma o bundle ID rende la master key inaccessibile senza conferma dell'utente: coerente con la regola di non cambiarli (CLAUDE.md).
- Perdere la master key (Portachiavi cancellato) rende illeggibile l'archivio: l'"Esporta backup cifrato" della fase 2 dovrà includere un modo per recuperarla.
- Fase 3: verificare il passaggio al Portachiavi "data protection" con access group condiviso con `iago-mcp`, con migrazione della chiave.
