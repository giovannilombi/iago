# Dati e archivio

## Dove stanno
Tutto è in `~/Library/Application Support/IAGO/`:

| Percorso | Contenuto |
|---|---|
| `iago.sqlite` | il database (GRDB): elementi, progetti, note, decisioni, segmenti, indici, impostazioni, coda dei lavori |
| `Items/<id>/` | i file di ogni elemento, cifrati: tracce audio, trascrizioni, documenti originali, allegati |
| `tmp/sessions/` | le registrazioni in corso, scritte di continuo; si svuota dopo la finalizzazione |
| `tmp/scratch/` | file temporanei in chiaro (riproduzione, lavoro del motore), svuotati all'avvio |

Il database è escluso da Time Machine (contiene l'indice di ricerca in chiaro); i file cifrati no.

## Modello
- **Elemento** (`Item`, ADR-0018) è un evento tipizzato: `call`, `email`, `document`. Ha progetto, categoria (una) e tag (molti), stream (molti, ADR-0038).
- **Gerarchia** cliente › progetto › stream (ADR-0038). Un progetto senza cliente sta in "Senza cliente"; un elemento classificato senza progetto in "Non definito" (ADR-0035).
- **Note** datate, su un elemento o su un progetto, anche vocali (ADR-0016, ADR-0021, ADR-0039). **Segnalibri** (`Marker`) con l'ora nella call (ADR-0024).
- **Punti chiave** (`Decision`) con tipo (decisione, attività, tappa…), fonte fino al minuto, persone, e catene di superamento anche multiple (ADR-0013, ADR-0014, ADR-0046, ADR-0052).
- **Suggerimenti** del motore, sempre da confermare (ADR-0009). **Collegamenti** tra elementi (`ItemLink`).
- **Pronto per la sincronizzazione** (ADR-0008): ogni riga ha `created_at`, `updated_at`, `deleted_at`, `version`, `device_id`; ogni modifica finisce in `change_log`.

## Migrazioni
Diciassette finora, da `v1` a `v17-summaries`. Una migrazione non si modifica mai dopo il rilascio: se ne aggiunge una nuova. Prima di installare una build che porta migrazioni nuove sull'archivio di un utente si fa un backup.

## Cifratura
- **File cifrati a blocchi** con AES-GCM (ADR-0027): si legge e si scrive a pezzi, anche file grandi, senza decifrarli tutti in memoria.
- **Una chiave per elemento**, a sua volta protetta da una chiave principale nel **Portachiavi** di macOS (ADR-0028).
- **Eliminazione definitiva = distruzione della chiave** (*crypto-shredding*): i file diventano illeggibili anche nelle copie e nei backup.
- **Cestino** di 30 giorni (ADR-0030); una registrazione scartata resta recuperabile per un'ora (ADR-0032).

## Backup ed esportazioni
- **Backup cifrato** con password scelta dall'utente: un unico file con tutto l'archivio, per un disco esterno o un Mac nuovo (ADR-0041).
- **Export** di progetto in Markdown (anche pensato per un LLM), **specchio Obsidian** facoltativo, TXT/MD di una trascrizione (`IAGOExport`).
- **Registro accessi:** download, letture e scritture di Claude, esportazioni, backup e aggiornamenti.

## Esempio iniziale
Un archivio nuovo e vuoto riceve una sola volta una struttura d'esempio senza contenuti (Cliente Test, Pj. Test 1 con due stream, Pj. Test 2), per mostrare come si organizza il lavoro (ADR-0066). L'app non contiene altri dati.
