# Fase 3 — Intelligenza e Claude: stato

Obiettivo (spec 18): Claude legge i progetti abilitati; ricerca per significato, estrazione con suggerimenti, chat con citazioni e vista a grafo, con un motore locale facoltativo e scaricabile dall'app.

| Blocco | Contenuto | Stato |
|---|---|---|
| 1 | Server MCP per Claude, flag per progetto, registro accessi, connessioni per ambito | ✅ mergiato (PR #16) |
| 2 | Vista a grafo | ✅ mergiato (PR #17); rifiniture grafiche a fine fase |
| 3 | Motore locale scaricabile (MLX, modello a scelta dell'utente: Qwen / Gemma), prova dei modelli, "Riordina testo"; titoli sempre Apple Intelligence (ADR-0048) | ✅ mergiato (PR #18) |
| 4 | Ricerca per significato (embedding + FTS5), ADR-0049 | 🚧 codice e test, prova utente in coda |
| 5 | Proposte automatiche (decisioni, attività, supera, nomi speaker, tag, progetto, collegamenti), ADR-0049 | 🚧 codice e test, prova utente in coda |
| 6 | Chiedi con citazioni e conversazioni salvate 48 h, servizio "Aggiungi a IAGO", ADR-0049 | 🚧 codice e test, prova utente in coda |
| 8 | Cartelle sorvegliate per le email: delta, regole, scartate (ADR-0050) | 🚧 codice e test, prova utente in coda |
| 9 | Riunioni: API locale di Teams, app di call sul microfono, Calendario, titolo provvisorio, mute (ADR-0051) | 🚧 codice e test, prova utente in coda |
| 10 | Superamenti multipli e tra tipi diversi (ADR-0052) | 🚧 codice e test, prova utente in coda |
| 11 | Cancellazione dell'eco di macOS sul microfono (ADR-0053), titolo della riunione giusta con più riunioni in corso (ADR-0051, modifica) | 🚧 codice, test e prova di misura; prova utente in coda |
| 12 | Sintesi per categoria con modelli Meetily/Hyprnote, categorie su due livelli, "Categorie e tag", barra laterale per clienti (ADR-0054) | 🚧 codice, test e prova sul motore vero; valutazione su call reali in coda |
| 13 | Sezione "Attività" (ADR-0055) | 🚧 codice e test, prova utente in coda |
| 7 | Scrittura da Claude via MCP: aggiungere e modificare note e decisioni, creare documenti e inserire elementi (email, testo). Trascrizioni, audio e originali restano non modificabili. Ogni scrittura va nel registro (ADR-0044, ADR-0047: anteprima e conferma) | ✅ mergiato (PR #17) |

## Blocco 1 — Server MCP (ADR-0043)

| Componente | Dove | Note |
|---|---|---|
| Protocollo | `IAGOMCP/MCPServer.swift` | JSON-RPC 2.0 su stdio, una riga per messaggio; `initialize`, `ping`, `tools/list`, `tools/call` |
| Strumenti | `IAGOMCP/IAGOTools.swift` | `list_projects`, `search`, `get_item`, `project_timeline`, `list_decisions`, `list_notes`, `get_thread`, `export_project`; solo progetti "Consultabile da Claude" |
| Eseguibile | `IAGO.app/Contents/MacOS/iago-mcp` (target `iago-mcp` in `project.yml`) | archivio in sola lettura + chiave dal Portachiavi; scrive solo una riga di registro per chiamata |
| Impostazioni | `App/Sources/UI/ClaudePane.swift`, `ScopeSettings.swift` | progetti abilitati; scelta della connessione (tutti, tutti + da classificare, cliente, progetto) con "Aggiungi a Claude Desktop", comando per Claude Code ed elenco delle connessioni già presenti; letture di Claude; tasto destro su progetto o cliente › Impostazioni… (Generale, Claude, Persone) |
| Barra laterale | `Hierarchy.swift` | progetto con puntino nel colore del testo, stream con trattino, cliente con quadratino colorato (clic: colore); logo Claude se consultabile, lucchetto se solo in IAGO (clic: impostazioni) |

## Blocco 7 — Scrittura tramite Claude (ADR-0044)

| Componente | Dove | Note |
|---|---|---|
| Permesso | `project.claude_writable` (migrazione `v11-mcp-write`) | "Claude può anche scrivere", spento di default, solo per i progetti consultabili |
| Strumenti | `IAGOMCP/IAGOWriteTools.swift` | `add_note`, `update_note`, `add_decision`, `update_decision`, `create_document`, `add_email`; nessuno strumento tocca trascrizioni, audio o originali |
| Provenienza e annullamento | `IAGOStore/MCPChanges.swift`, `ViaClaudeBadge` | `input`/`origin`/`source` = `mcp`; tabella `mcp_change`; "Inserita/Modificata tramite Claude (MCP)"; Impostazioni › Claude › Annulla |
| Aggiornamento dell'app | `externalChangeCounter` (`PRAGMA data_version`) | IAGO ricarica entro 2 s quando scrive il server |
| Anteprima e contesto (ADR-0047) | `IAGOWriteTools.swift` (`WritePlan`, codice di conferma HMAC), `IAGOTools.writingGuide` | ogni scrittura: anteprima con data, posizione in timeline e dubbi (voci simili, date, stream, ordine della catena), poi conferma con codice; data di default adesso, `date="source"`; stream e collegamenti; `list_decisions` con `query`; annotazioni MCP lettura/scrittura; `write_batch` (fino a 20 note e punti chiave, un'anteprima e una conferma); avviso su note quasi uguali; persone e tag nell'anteprima |
| Stream delle note | tabella `note_stream` (migrazione `v12-note-stream`), `NoteEditor`, timeline dello stream | anche a mano dall'app |
| Permessi dei client | `ClaudePane.permissionsGroup`, `ClaudeConnection.allowInClaudeCode` | passi per Claude Desktop; `mcp__<connessione>` in `~/.claude/settings.json` con conferma |

## Blocco 2 — Vista a grafo (ADR-0045)

| Componente | Dove | Note |
|---|---|---|
| Modello | `IAGOCore/Graph.swift` | nodi e archi, `asOf` (cursore temporale), `limited` (500 nodi: via le note, poi gruppi per mese o anno) |
| Proiezione | `IAGOIntelligence/GraphBuilder.swift` | progetti, clienti, elementi, persone (entità, speaker, corrispondenti email), tag, decisioni, note |
| Vista | `App/Sources/UI/GraphView.swift` | quarta vista "Grafo"; Centrato/Tutto, tipi, data, zoom, trascinamento; clic → pannello di destra o scheda; doppio clic espande |

## Blocco 3 — Motore locale (ADR-0048)

| Componente | Dove | Note |
|---|---|---|
| Protocollo | `IAGOCore/LanguageModel.swift` (`LLMProvider`, `LLMRequest`) | le funzioni lo ricevono dall'app solo se c'è un motore scelto |
| Catalogo, download, scelta | `IAGOEngine` (`EngineCatalog`, `EngineDownloader`, `EngineLibrary`) | Qwen 3.5 4B e 9B, Gemma 4 12B, MLX 4 bit, fissati a commit con SHA-256 di ogni file (`scripts/make-engine-catalog.py`); ripresa con Range; `.verified`; `active.json` |
| Adattatore MLX | `App/Sources/Engine/MLXProvider.swift` | `mlx-swift-lm` 3.32.3 + `swift-transformers` 1.3.4 (Tokenizers); solo cartelle locali, downloader che rifiuta; scarica la memoria dopo 10 min |
| Servizio e UI | `EngineService`, `EngineViews.swift` | Impostazioni › Motore; "Serve un motore locale"; "Il motore è pronto"; percentuale nella barra dei menu; Spazio |
| Riordina testo | `IAGOIntelligence/TextTidier.swift`, `NoteEditor` | solo con motore; anteprima Prima/Dopo, "Sostituisci" |
| Prova dei modelli | `EngineBench` (`--args -IAGOEngineBench 3`) | rapporto in `Application Support/IAGO/bench-out/` |
| Verifiche | `scripts/test-engine.sh`, `.github/workflows/engine.yml` (solo manuale), `check-network-apis.sh` | MLX non entra nella CI automatica; FoundationModels solo in `TitleSuggester` |

## Blocchi 4-6 — Ricerca, proposte, Chiedi (ADR-0049)

| Componente | Dove | Note |
|---|---|---|
| Pezzi e vettori | `IAGOStore/Intelligence.swift` (`chunk`, `v13-intelligence`), `IAGOIntelligence/SemanticSearch.swift` | turni di parola 200-400 parole; vettori in BLOB, Accelerate; `HybridSearch` RRF |
| Modello di ricerca | `EngineCatalog.embedding` (Qwen3 Embedding 0.6B), `App/Sources/Engine/MLXEmbedder.swift` | scaricato con il primo motore |
| Lavori in background | `IntelligenceService` | indicizza, proposte automatiche per gli elementi nuovi, "Cerca proposte"; pausa durante registrazioni e chat |
| Proposte | `suggestion`, `SuggestionEngine`, `Suggestions.swift` | Conferma / Modifica / Scarta; segni in elenco e timeline; "Da confermare" in Punti chiave |
| Chiedi | `ChatAnswerer`, `ChatPanel` (⌘K), `conversation` (`v14-conversations`) | fonti numerate; conversazioni 48 h, Conserva, Fissa; "Nuovo materiale aggiunto" |
| Servizi | `ServiceProvider`, `NSServices` | "Aggiungi a IAGO" sul testo selezionato |

## Cartelle sorvegliate (ADR-0050)

| Componente | Dove | Note |
|---|---|---|
| Regole | `IAGOIngest/ImportRules.swift` | inviti/risposte meeting, risposte automatiche, newsletter (spenta), esclusioni e assegnazioni dell'utente |
| Registro | `IAGOStore/WatchedFolders.swift` (`v15-watched-folders`) | delta per percorso, dimensione, data, SHA-256; doppioni per Message-ID |
| Servizio e UI | `FolderImporter`, `WatchedFoldersViews.swift` | Impostazioni › Email e persone; "Importate"; "Importa comunque" |

## Riunioni (ADR-0051)

| Componente | Dove | Note |
|---|---|---|
| API locale di Teams | `App/Sources/Calls/TeamsLocalAPI.swift`, `IAGOCore/TeamsMeeting.swift` | ws://127.0.0.1:8124, abbinamento con `query-state`, token nel Portachiavi |
| App di call sul microfono | `IAGOCapture/CallActivity.swift` | Teams, Zoom, Webex, FaceTime, Slack (non i browser) |
| Calendario | `MeetingCalendar` (EventKit) | titolo provvisorio, avviso all'orario d'inizio |
| Coordinamento | `CallDetector` | Chiedi / Registra automaticamente / Non fare nulla; "La call è finita: fermo?"; mute → silenzio sulla traccia mic (`micMuted`) |
