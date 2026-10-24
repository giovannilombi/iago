# ADR-0036 — Indice di ricerca FTS5 e controllo delle API di rete

- Stato: accettato
- Data: 2026-10-12
- Riferimenti spec: FR-70, FR-71, FR-120, sez. 4.2, 9.3, 10.2

## Contesto
La ricerca testuale (fase 2) deve trovare passaggi di trascrizioni, note e documenti e aprire l'elemento al punto giusto. I file sono cifrati per elemento: cercare decifrando ogni volta sarebbe lento. Serve inoltre una garanzia verificabile che IAGO non usi la rete fuori dai casi ammessi.

## Decisione
- Tabella virtuale **FTS5** `search_index` (tokenizer `unicode61`, accenti rimossi): una riga per segmento di trascrizione (con `at_sec`), per paragrafo di documento, per nota. Colonne non indicizzate `item_id`, `project_id`, `source`, `source_id`.
- Il **testo è in chiaro nel database**, come già i titoli e le note (spec 9.3): il database è escluso da Time Machine e l'eliminazione definitiva rimuove le righe (crypto-shredding + `secure_delete`).
- Aggiornamento sincrono a ogni scrittura (trascrizione, documento, nota, cambio progetto); ricostruzione completa una volta all'avvio dopo l'aggiornamento (`search_index_version`).
- Query dell'utente trasformata in parole tra virgolette con ricerca per prefisso: nessuna sintassi FTS iniettabile.
- **Controllo di rete**: `scripts/check-network-apis.sh` (anche in CI) fallisce se nel codice di IAGO compaiono API di rete fuori da `ModelManager` (download dei modelli). In Impostazioni › Privacy un link a LuLu per la verifica indipendente.

## Conseguenze
- La ricerca semantica (embedding, fase 3) si affiancherà all'FTS con fusione dei risultati (spec 10.2).
- Le dipendenze non sono analizzate dallo script: FluidAudio resta offline (`ModelHub.offlineMode`).
