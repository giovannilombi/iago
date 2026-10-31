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
- **Lavoro aperto** (ADR-0074): in `decision` responsabile e attesa (`owner_id`, `waiting_on_id` verso `entity`), `due_at`, `waiting_until`, `priority`, `starts_at`, `estimate`, `severity`, `happened_at`, `outcome`, `outcome_kind`, `derived_from_id`, `recurrence`, `closed_at`; tabelle `decision_dependency`, `checklist` e `checklist_item` (sotto-voci di un'attività o liste di progetto), `board_column` e `board_place` (colonne libere di ogni board); `project.work_mode`.
- **Suggerimenti** del motore o di Claude, sempre da confermare (ADR-0009). Sintesi e suggerimenti hanno `origin` (`engine`, `claude` o, per i nomi degli speaker, `voice`) e `model`; un punto chiave confermato da un suggerimento conserva `model` (ADR-0070). **Collegamenti** tra elementi (`ItemLink`).
- **Voci** (ADR-0073, solo se attive): `item_voice` tiene l'impronta di ogni speaker di una call, cifrata con la chiave dell'elemento; `voice` solo il nome della persona. L'impronta di una persona è la media delle sue call, calcolata al momento: eliminare una call la toglie. Le voci non entrano nel `change_log` né negli export.
- **Presenti** (migrazione `v24-attendees`): `item_attendee` (`item_id`, `name`, `position`), chi c'era a una riunione secondo l'utente (ADR-0031); proposti come nomi degli speaker, nelle esportazioni e in *Condividi*.
- **Nomi degli speaker** (migrazione `v22-speaker-names`): `item_speaker.merged_into`, lo speaker della stessa call a cui uno è stato unito; `name_alias` (`alias` normalizzato → `name`), i soprannomi che l'utente ha detto essere la stessa persona («Lello» → «Antonello»).
- **Due trascrizioni** (ADR-0078): `transcript_json` è la principale, letta da sintesi, proposte, export e MCP; `alternate_transcript_json` l'altra (Teams accanto a IAGO o viceversa), nel suo file `transcript-alt.json`. Scambio ed eliminazione in `IAGOStore/Transcripts.swift`. La ricerca indicizza anche l'altra: le sue righe di `search_index` hanno `source_id` `<item>#alt-<teams|iago>-<segmento>` (`Archive.indexAlternateTranscript`); l'indice si ricostruisce una volta all'aggiornamento (`search_index_version` = 2).
- **Trascrizione della sintesi** (migrazione `v23-summary-transcript`): `summary.transcript_source` (`iago`, `teams`) è la trascrizione principale quando la sintesi è stata scritta; nil per quelle di prima.
- **Pronto per la sincronizzazione** (ADR-0008): ogni riga ha `created_at`, `updated_at`, `deleted_at`, `version`, `device_id`; ogni modifica finisce in `change_log`.

## Migrazioni
Ventuno finora, da `v1` a `v21-work` (lavoro aperto, ADR-0074: solo colonne e tabelle nuove); `v20-voices` aggiunge le impronte delle voci (ADR-0073); `v19-screenshots` aggiunge le schermate delle call con minuto e testo letto (ADR-0072); `v18-provenance` registra chi ha prodotto sintesi, proposte e punti chiave confermati (ADR-0070). Una migrazione non si modifica mai dopo il rilascio: se ne aggiunge una nuova. Prima di installare una build che porta migrazioni nuove sull'archivio di un utente si fa un backup.

## Cifratura
- **File cifrati a blocchi** con AES-GCM (ADR-0027): si legge e si scrive a pezzi, anche file grandi, senza decifrarli tutti in memoria.
- **Una chiave per elemento**, a sua volta protetta da una chiave principale nel **Portachiavi** di macOS (ADR-0028).
- **Eliminazione definitiva = distruzione della chiave** (*crypto-shredding*): i file diventano illeggibili anche nelle copie e nei backup.
- **Cestino** di 30 giorni (ADR-0030); una registrazione scartata resta recuperabile per un'ora (ADR-0032).

## Backup ed esportazioni
- **Backup cifrato** con password scelta dall'utente: un unico file con tutto l'archivio, per un disco esterno o un Mac nuovo (ADR-0041).
- **Export** di progetto in Markdown (anche pensato per un LLM), **specchio Obsidian** facoltativo, TXT/MD di una trascrizione (`IAGOExport`).
- **Condividi un elemento** (ADR-0080, `IAGOExport/ItemShare.swift`): le parti scelte (scheda Markdown, trascrizioni, audio, tracce, originali, schermate) decifrate in una cartella temporanea (`IAGO-Condividi`, svuotata a ogni condivisione), facoltativamente in uno zip con `ditto`, poi `NSSharingServicePicker` o una cartella scelta. Le impronte delle voci non sono asset e non ci sono mai. Nel registro accessi come `export/share`.
- **Registro accessi:** download, letture e scritture di Claude, esportazioni, backup e aggiornamenti.

## Esempio iniziale
Un archivio nuovo e vuoto riceve una sola volta, finita la scelta della lingua, i **progetti di esempio** (`IAGOStore/ExampleArchive.swift`, ADR-0066): tre clienti inventati con call trascritte, email, documenti, sintesi, punti chiave, proposte e note, nella lingua dell'app e datati intorno al giorno di creazione. Gli elementi hanno `capture_meta = example` e non contano nei primi passi; gli ID stanno nell'impostazione `example_ids` e `Archive.removeExample` li elimina. Gli archivi creati prima della 1.2.10-beta tengono la vecchia struttura «Cliente Test».
