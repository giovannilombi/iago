# Fase 2 — Organizzazione: stato

Obiettivo (spec 18): IAGO come cronologia del progetto. Già anticipati nella fase 1: timeline, documenti e OCR, note con allegati, trascrizioni Teams, gestione di progetti e tag, cestino.

| Blocco | Contenuto | Stato |
|---|---|---|
| 1 | Garanzia di rete e ricerca (FTS5, filtri, ordinamenti) | ✅ mergiato (PR #9) |
| 2 | Registro decisioni | ✅ mergiato (PR #10) |
| 3 | Gerarchia Cliente › Progetto › Stream | ✅ mergiato (PR #11) |
| 4 | Note di progetto e note vocali | ✅ mergiato (PR #12) |
| 5 | Email (anche trascinate da Outlook), persone del cliente/progetto, collegamenti | ✅ mergiato (PR #13) |
| 6 | Export per LLM, Obsidian, backup cifrato ed export audio, Markdown correggibile | ✅ mergiato (PR #14, rifiniture PR #15) |

## Blocco 1 — Rete e ricerca

| Componente | Dove | Note |
|---|---|---|
| Controllo di rete | `scripts/check-network-apis.sh`, CI | fallisce se compaiono API di rete fuori da `ModelManager`; link a LuLu in Impostazioni › Privacy |
| Indice | `IAGOStore/Search.swift`, migrazione `v5-search` | FTS5 per segmento, paragrafo e nota; accenti e maiuscole ignorati; aggiornato a ogni scrittura, ricostruito una volta all'avvio (ADR-0036) |
| Ricerca | `App/Sources/UI/SearchAndFilters.swift` | campo nella barra della finestra; risultati per passaggio raggruppati per elemento, parola trovata in grassetto; il clic apre l'elemento e fa partire l'audio da quel punto; dentro un progetto cerca solo nel progetto |
| Filtri e ordinamento | `FilterBar`, `AppModel.LibraryFilter` | categoria, tag (più di uno), tipo, stato, periodo; ordinamento per data, titolo, durata, progetto; valgono per elenco e timeline |

## Blocco 2 — Registro decisioni

| Componente | Dove | Note |
|---|---|---|
| Archivio | `IAGOStore/Decisions.swift`, migrazione `v6-decisions` | decisioni, persone, tag; catena "supera"; fonte eliminata segnalata; indicizzate nella ricerca (ADR-0037); 5 test |
| Vista Decisioni | `App/Sources/UI/Decisions.swift` | a timeline; voce "Decisioni" nella barra laterale (tutte) e terza vista accanto a Elenco/Timeline (per progetto); filtri stato (default attive), persona, tag; clic → audio dal punto o fonte; la superata sta sotto chi la supera se hanno lo stesso giorno |
| Editor | `DecisionEditor`, `TokenField` | persone e tag con suggerimenti per somiglianza e conferma prima di creare un nome simile; progetto obbligatorio per le decisioni scritte a mano (quelle da una fonte seguono la fonte); avviso se la data è precedente alla decisione superata, con proposta di allinearla |
| Ricerca | `SearchScopeBar` | selettori Tutto / Trascrizioni / Note / Documenti / Decisioni; intestazione "nel progetto «X»" o "in tutto l'archivio" con passaggio dall'uno all'altro; cambiando sezione la ricerca resta, l'icona accanto al campo riporta ai risultati |
| Creazione | scheda elemento, pannello post-registrazione | segnalibro → "Diventa decisione…"; tasto destro su una frase → "Segna come decisione…"; documento: copia il passaggio e tasto destro; nota → "Promuovi a decisione"; "Aggiungi decisione" / "Nuova decisione" |
| Timeline | `ProjectTimeline` | decisioni come sigillo verde sulla linea, alla loro data (nascoste se è attivo un filtro sugli elementi) |

## Blocco 3 — Gerarchia Cliente › Progetto › Stream

| Componente | Dove | Note |
|---|---|---|
| Archivio | `IAGOStore/Hierarchy.swift`, migrazione `v7-hierarchy` | clienti, stream, stream multipli su elementi e decisioni, ambiti cliente/stream per libreria, decisioni e ricerca (ADR-0038); 4 test |
| Barra laterale | `App/Sources/UI/Hierarchy.swift` | albero: fissati, clienti › progetti › stream, "Senza cliente"; trascina un progetto su un cliente; menu contestuali (nuovo stream, sposta nel cliente, rinomina, elimina); "+ Aggiungi" → progetto o cliente |
| Viste | `ViewModePicker`, `FilterBar` | cliente = elementi/timeline/decisioni di tutti i suoi progetti; stream = vista filtrata; nel progetto filtro "Stream"; pallini colorati su schede e decisioni |
| Scheda e decisioni | `MetadataEditor`, `DecisionEditor` | campo Stream a scelta multipla con "+ Nuovo stream"; avviso se lo spostamento di progetto toglie gli stream |
| Ricerca | `SearchScopeBar` | "Cambia ambito": stream → progetto → cliente → tutto l'archivio |
| Impostazioni › Progetti | `ClientsPane`, `ProjectStreamsEditor` | clienti (rinomina, archivia, elimina), cliente di ogni progetto, stream di ogni progetto |

## Blocco 4 — Note di progetto e note vocali

| Componente | Dove | Note |
|---|---|---|
| Note di progetto | `Archive.notes(projectID:)`, migrazione `v8-asset-owner` | note senza elemento, allegati cifrati con chiave del progetto, distrutti con il progetto (ADR-0039); 2 test |
| Timeline | `ProjectTimeline` | note di progetto e degli elementi alla loro data (gialle, microfono se dettate); clic, modifica, promuovi a decisione, elimina; "Nota di progetto" in alto nella vista progetto |
| Note vocali | `App/Sources/UI/VoiceNotes.swift`, `TranscriptionPipeline.dictate` | pulsante "Detta" nell'editor (aggiungi in coda / sostituisci, livello, durata), trascrizione immediata, audio eliminato al salvataggio, "Riprova / Scarta audio", recupero all'avvio |
| Barra dei menu | `StatusItemController`, `VoiceNotePanel` | "Nota vocale…" (disattivata durante una call): pannello che ascolta subito, destinazione = ultimo elemento o un progetto; una call che parte ferma e trascrive la nota |
| Verifica | hook DEBUG `-IAGODebugDictate <file>` | frase sintetica di 7 s trascritta esatta in 12 s incluso il caricamento del modello |

## Blocco 5 — Email, persone e collegamenti

| Componente | Dove | Note |
|---|---|---|
| Parser | `IAGOIngest/EmailParser.swift` | MIME locale, HTML → Markdown senza WebKit (niente immagini remote), intestazioni da screenshot (ADR-0040); 3 test |
| Archivio | `IAGOStore/Email.swift`, migrazione `v9-email` | email_meta, conversazioni in qualsiasi ordine di import, item_link, contatti con ruolo, progetto suggerito; 4 test |
| Import | `ArchiveService`, `EmailImportSheet` | `.eml`/`.emlx` da Importa… o trascinati (anche da Outlook/Mail come file promessi): conferma con allegati (immagini < 20 KB escluse), progetto suggerito, direzione |
| Nuova email | `NewEmailSheet` (barra laterale "Nuova email…") | campi a mano o "Da screenshot negli appunti" (OCR + intestazioni proposte) |
| Scheda | `EmailHeaderSection`, `LinksSection` | intestazioni, direzione modificabile, conversazione; "Collegamenti" su tutti gli elementi con "Collega a…" |
| Liste e timeline | `ItemIcon` | icona per tipo, direzione, mittente, numero di collegamenti |
| Persone | `PeopleSheet`, Impostazioni › Email e persone | i tuoi indirizzi; colleghi interni; clienti/fornitori su cliente o progetto (tasto destro → Persone…) |
| Import multiplo | `EmailBatchSheet`, `Archive.classifyEmail` | più email trascinate insieme: pila + "Una alla volta" (3 di 12, Salta) o "Tutte insieme" (tabella precompilata: conversazione, persone, domini, nome nell'oggetto; dubbi in arancione in cima; assegnazione multipla); doppioni rifiutati dall'archivio (Message-ID); 1 test |
| Domini noti | `DomainRulesEditor`, `Archive.roles(for:)` | `@dominio` → interno/cliente/fornitore per tutta l'app (sottodomini inclusi); domini del cliente nella sua "Persone…"; etichette accanto agli indirizzi; 1 test |

## Blocco 6 — Export, backup, Obsidian, Markdown correggibile

| Componente | Dove | Note |
|---|---|---|
| Export per LLM | `IAGOExport/ProjectExporter.swift`, `LLMExportSheet` | icona Esporta nella vista (progetto, cliente, stream, filtri): indice, registro decisioni, elementi e note in ordine cronologico, stima token, copia o salva; 1 test |
| Export audio | `AudioExportSheet` | .m4a non cifrati (+ trascrizione .md) della vista o di tutto l'archivio (Impostazioni › Backup) |
| Backup cifrato | `IAGOStore/Backup.swift`, `BackupService`, Impostazioni › Backup e trasferimento | Apple Encrypted Archive con password; DB + file + chiave; ripristino al riavvio, archivio precedente conservato; anche dall'onboarding (nuovo Mac); 1 test andata/ritorno |
| Obsidian | `IAGOExport/ObsidianMirror.swift`, Impostazioni › Obsidian | vault + progetti scelti, aggiornamento automatico, file con iago_id solo; 1 test |
| Markdown correggibile | `updateContentMarkdown`, "Correggi il testo…" | testo automatico conservato e ripristinabile, ricerca aggiornata; 1 test |
| Archivi sostituiti | `BackupService.replacedArchives`, Impostazioni › Backup | elenco con spazio occupato, eliminazione con tripla conferma (avviso, DELETE, ultima conferma): cartella + chiave nel Portachiavi |
| Importa | `ImportView` (barra laterale) | da file, dagli appunti (anteprima prima di importare: file, immagine con OCR, testo), da testo (documento `.md`), email .eml, email senza file; il trascinamento resta su tutta la finestra |
| Elenchi nelle email | `Bullets.join` in `EmailParser` | punti elenco di Outlook e `<li><p>` ricomposti, menzioni senza `<mailto:…>`; email già importate riconvertite una volta dall'originale (testi corretti a mano esclusi); 4 test |
