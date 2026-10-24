# Fase 1 — MVP: stato

Obiettivo (spec 18): flusso completo registra → classifica → trascrivi (conservando o eliminando l'audio) → leggi → esporta → elimina, con archivio cifrato e nessuna chiamata di rete non prevista.

Il lavoro è diviso in blocchi, ognuno con il suo branch e la sua PR.

| Blocco | Contenuto | Stato |
|---|---|---|
| 1 | Archivio e cifratura (`IAGOStore`) | ✅ mergiato (PR #3) |
| 2 | Dalla cattura all'archivio | ✅ mergiato (PR #4) |
| 3 | Trascrizione nell'app | ✅ mergiato (PR #5) |
| 4 | Finestra principale, scheda, pannello post-registrazione, cestino | ✅ mergiato (PR #6) |
| 5 | Onboarding, impostazioni, icona | ✅ codice e prova utente |

## Blocco 1 — Archivio e cifratura

| Componente | Dove | Note |
|---|---|---|
| Database | `IAGOStore/AppDatabase.swift`, `Migrations.swift` | GRDB 7.11.1, WAL, `secure_delete`, migrazione `v1` con le tabelle della fase 1 (incluse `item.type`, `marker`, `note`, `trashed_at`) |
| Righe e sync | `Records/` | campi di sync su ogni tabella utente; ogni scrittura passa da `SyncWriter` (versione, `device_id`, `change_log` nella stessa transazione); tombstone per le eliminazioni |
| Chiavi | `KeyStore.swift` | master key nel Portachiavi (ADR-0028), chiave per elemento in `item_key` |
| File cifrati | `EncryptedFile.swift` | formato a blocchi AES-GCM da 1 MB (ADR-0027), SHA-256 del contenuto in chiaro |
| Archivio | `Archive.swift` | elementi, progetti, categorie predefinite (FR-100), tag normalizzati con suggerimenti (FR-101), note (FR-170…176), segnalibri, speaker (FR-41), asset cifrati, cestino a 30 giorni (ADR-0030), eliminazione definitiva (crypto-shredding), impostazioni, registro accessi |

Il Portachiavi reale (`KeychainMasterKeyStore`) si verifica nell'app firmata, nel blocco 2: i test usano una chiave in memoria.

## Blocco 2 — Dalla cattura all'archivio

| Componente | Dove | Note |
|---|---|---|
| Percorsi | `IAGOCapture/StoragePaths.swift` | `iago.sqlite`, `Items/`, `Models/`, `tmp/sessions`, `tmp/finalized`, `tmp/scratch` (svuotata all'avvio) |
| Archiviazione | `IAGOStore/RecordingArchiver.swift`, `App/Sources/ArchiveService.swift` | allo Stop il finalizzatore scrive in `tmp/finalized/`, poi le tracce vengono cifrate nell'archivio come elemento `Unclassified · …` (FR-17) con segnalibri in `marker` e pause/dispositivi in `capture_meta`; il chiaro si cancella solo dopo la copia cifrata. Idempotente: all'avvio si riprende ciò che è rimasto in `tmp/finalized/` |
| Recupero | `AppDelegate` | prima il recupero delle sessioni interrotte, poi l'archiviazione di tutto ciò che è in attesa |
| Fase 0 | ADR-0029 | `Recordings/` importata e rimossa al primo avvio |
| Import (FR-30, FR-31) | `IAGOCapture/AudioFileConverter.swift`, menu "Importa file…", trascinamento sull'icona | conversione in m4a (AAC) in `tmp/scratch`, traccia `audio_import` cifrata, data = creazione del file, titolo = nome del file |
| Time Machine | `ArchiveService` | cartella IAGO esclusa (impostazione per includerla nel blocco 5) |
| Cestino | `ArchiveService` | svuotamento dei contenuti scaduti all'avvio e ogni 24 ore |

Il ring buffer previsto per i callback audio (questione aperta 4 della fase 0) non serve: gli IOProc sono creati con una coda dispatch (`AudioDeviceCreateIOProcIDWithBlock`), quindi il blocco non gira sul thread real-time di Core Audio e l'allocazione non causa glitch.

## Blocco 3 — Trascrizione nell'app

| Componente | Dove | Note |
|---|---|---|
| Coda dei job | `IAGOStore/Jobs.swift` | tabella `job`, un job alla volta a priorità `.utility`, priorità, progresso, tentativi, annullamento; i job interrotti ripartono al riavvio; attesa se non è permesso partire (opzione "solo con alimentazione", spec 4.3) |
| Modelli | `IAGOTranscription/ModelManager.swift` | manifest con fonte fissa e SHA-256 (whisper turbo; VAD e diarizzazione FluidAudio con impronta dell'intera cartella); verifica a ogni avvio, download solo su azione dell'utente con registro accessi, FluidAudio sempre offline e caricato da `Models/FluidAudio` di IAGO |
| Trascrizione | `App/Sources/TranscriptionService.swift` | tracce decifrate in `tmp/scratch` solo durante il job; `transcript.json` cifrato, poi TXT e MD (`IAGOExport/TranscriptRenderer.swift`, sez. 11.1 con Addendum); speaker in `item_speaker`; "trascrivi ed elimina l'audio" rilegge il JSON e ne verifica lo SHA-256 prima di eliminare l'audio in modo definitivo (FR-54) |
| Diarizzazione | `TranscriptionPipeline` | se FluidAudio rifiuta l'audio (troppo breve o senza parlato) la trascrizione resta valida con un solo speaker |
| Menu bar | `StatusItemController` | icona e percentuale durante trascrizione e download, "Annulla trascrizione", "Scarica modelli di trascrizione…" quando mancano |
| Notifiche | `Notifier` | se le notifiche sono disattivate, i messaggi importanti (trascrizione completata, registrazione recuperata) compaiono in una finestra |

Le azioni "Trascrivi" arrivano nell'interfaccia con il pannello post-registrazione e la scheda dell'elemento (blocco 4); fino ad allora ci sono voci di menu di debug.

## Blocco 4 — Finestra principale, scheda, pannello, cestino

| Componente | Dove | Note |
|---|---|---|
| Finestra principale | `App/Sources/UI/MainView.swift`, `WindowManager.swift` | barra laterale (Da classificare, Recenti, Progetti, Categorie, Tag, Cestino), elenco con stato (FR-73), dettaglio; trascinamento di file sulla finestra = import (FR-30); icona nel Dock solo mentre una finestra è aperta |
| Scheda elemento | `ItemDetailView.swift`, `MetadataEditor.swift` | titolo, data, progetto (anche nuovo), categoria, tag con suggerimenti (FR-101); lettore con scelta traccia e timestamp cliccabili (FR-52); speaker rinominabili (FR-41); vista Markdown; segnalibri; note con data e tipo (FR-170…173); file con dimensione, esporta, copia, elimina (FR-53, FR-60); trascrivi/ritrascrivi con conferma (FR-55); "Più persone nella stanza" (ADR-0031); elimina con scelta cestino/definitivo e destinazione delle note (FR-176, ADR-0030) |
| Pannello post-registrazione | `PostRecordingView.swift` | dopo lo Stop (non per le sessioni recuperate): metadati, segnalibri, le tre azioni (FR-20); chiuso senza scelta l'elemento resta da classificare (FR-21) |
| Cestino | `TrashView.swift` | ripristina, elimina definitivamente, svuota, giorni rimanenti |
| Aggiornamento | `AppModel.swift`, `Archive.changes()` | la UI si ricarica a ogni modifica del database; TXT e MD rigenerati dopo modifiche a metadati, speaker e note |
| Uscita | `TranscriptionService.shutdown()` | il modello whisper viene liberato prima di uscire (altrimenti whisper.cpp va in crash alla chiusura) |

### Aggiunte su richiesta dell'utente (blocco 4)

| Cosa | Dove | Note |
|---|---|---|
| Barra di registrazione nella finestra | `ProjectsAndRecording.swift`, `WindowManager` | accessorio della barra del titolo: stato, durata, microfono, Segna momento, Pausa, Scarta, Stop |
| "Scarta" e "Scartate temporanee" | ADR-0032 | eliminazione definitiva dopo 1 ora |
| Progetti | `ProjectNameMatcher`, `NewProjectSheet`, sidebar | controllo doppioni con conferma esplicita, "+ Aggiungi", fissa in alto, ordine per ultimo uso, sezioni a fisarmonica, clic destro per spostare gli elementi |
| Timeline | `ProjectTimeline.swift` | anticipata dalla fase 2 (FR-80): vista principale del progetto |
| "Più persone nella stanza" | ADR-0031 | diarizzazione anche della traccia mic |
| Import generico, Teams, allegati nelle note | ADR-0033, `Packages/IAGOIngest` | OCR e documenti anticipati dalla fase 2 |
| Pulsanti testuali | `ActionLink.swift` | azioni su due colonne nel pannello e nella scheda |

## Blocco 5 — Onboarding, impostazioni, icona, installazione

| Componente | Dove | Note |
|---|---|---|
| Onboarding | `App/Sources/UI/OnboardingView.swift` | al primo avvio: benvenuto e privacy, "Cosa serve" (niente da installare; controllo macOS, Apple Silicon, spazio), nome, microfono, audio di sistema con prova di 5 s (frase pronunciata da `/usr/bin/say`, perché il tap esclude IAGO), notifiche, modelli |
| Impostazioni | `App/Sources/UI/SettingsView.swift` | Generale (nome, avvio al login), Audio (microfono fisso), Trascrizione (Whisper o Parakeet, lingua, azione dopo lo Stop FR-22, solo con alimentazione), Categorie, Privacy (Time Machine, registro accessi), Spazio (archivio e modelli), Informazioni; logo, autore e licenza (ADR-0034) |
| Icone | `MenuBarIcon.swift`, `Assets.xcassets` | icona dell'app dal logo; barra dei menu con il contorno del logo (template) e pallino di stato |
| Installazione | `scripts/install-app.sh` | build Release firmata copiata in `/Applications`: IAGO si apre da Launchpad, Spotlight, Dock o Scrivania |

Prima della consegna: nessun riferimento "Debug" visibile all'utente (le build di sviluppo restano in `build/`, esclusa da Spotlight).
