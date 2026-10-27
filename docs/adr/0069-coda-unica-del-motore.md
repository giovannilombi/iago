# ADR-0069 — Coda unica del motore e memoria

- Stato: accettato
- Data: 2026-10-27
- Riferimenti: ADR-0048 §6 (job del motore uno alla volta), ADR-0049 (motore ed embedding mai insieme, la chat ha la precedenza, sospensione con poca memoria), ADR-0054 (sintesi), ADR-0023 (trascrizione); indicazioni dell'utente del 2026-10-27

## Contesto
- Su Mac con 16 GB IAGO ha saturato la memoria durante sintesi, proposte e punti chiave.
- ADR-0048 e ADR-0049 promettevano un lavoro pesante alla volta, ma il codice non lo faceva:
  - il lavoro dell'IA girava in un ciclo a parte, che non aspettava la trascrizione: LLM e Whisper/Parakeet potevano lavorare insieme;
  - la chat partiva anche durante una sintesi: due generazioni sullo stesso modello, con due cache;
  - il modello di embedding e il modello di testo potevano restare caricati insieme;
  - nessuna reazione alla memoria scarsa di macOS;
  - MLX tiene da parte i buffer liberati fino a tutta la memoria che può usare.
- Un testo con una riga enorme (un JSON compatto) finiva intero in una sola richiesta: la causa probabile dei blocchi segnalati da un tester (vedi la correzione del 2026-10-27, `TextPieces`).
- Su Apple Silicon la GPU usa la RAM: modello, trascrizione e app dell'utente devono starci insieme.

## Decisione
- **Una corsia unica** (`EngineLane`, in `IAGOEngine`) per tutto il lavoro pesante: trascrizione, modello di testo, embedding. Un lavoro alla volta, sempre, su ogni Mac: la GPU è una, e due lavori insieme non finiscono prima.
- **La chat ha la precedenza** (lavoro *interattivo*: Chiedi, la ricerca per significato, *Riordina testo*):
  - un lavoro in sottofondo in corso viene **interrotto subito** e poi **rifatto dallo stesso passo**: un blocco di una sintesi o delle proposte, un gruppo dell'indicizzazione. Si perde al massimo un blocco;
  - MLX interrompe la generazione a ogni token quando il task viene cancellato; la risposta parziale non si usa mai (`MLXProvider` ricontrolla la cancellazione);
  - una **trascrizione non si può interrompere**: la chat aspetta la sua fine. Sui Mac da **32 GB** in su la chat può girare accanto alla trascrizione.
- **Memoria:**
  - limite alla cache dei buffer di MLX: 256 MB sotto i 32 GB, 1 GB sopra;
  - con la **pressione di memoria** segnalata da macOS: la cache di MLX si svuota e il lavoro in sottofondo si ferma per 90 secondi (5 minuti e modelli liberati se la pressione è critica); la chat non viene toccata;
  - il limite di memoria di MLX resta quello predefinito: abbassarlo fa aspettare le allocazioni e una richiesta potrebbe bloccarsi.
- **Mac con meno di 32 GB:**
  - **proposte automatiche e sintesi automatiche spente di default**: partono dai pulsanti della scheda («Cerca proposte», «Genera sintesi»), e l'utente può accenderle in Impostazioni › Motore. Il default si calcola su ogni Mac e non si salva, perché l'archivio può passare da un Mac all'altro; una scelta dell'utente resta;
  - il modello si **libera alla fine di ogni lavoro in sottofondo**, invece che dopo 10 minuti di inattività (dopo la chat resta caricato, perché di solito segue un'altra domanda).
- **Gemma 4 12B richiede almeno 24 GB:** sotto, arriva a 12,4 GB, oltre quello che macOS concede alla GPU. Non si può scaricare né usare; se era attivo, IAGO passa al modello installato più grande che entra (di solito Qwen 3.5 9B) e lo dice con una notifica. Prima IAGO avvisava ma lasciava scegliere (ADR-0048).
- Le regole stanno in `EnginePolicy` (`IAGOEngine`), con i test; il catalogo generato non cambia.

## Conseguenze
- Supera i punti di ADR-0048 §6 e ADR-0049 su "uno alla volta", "la chat ha la precedenza" e "poca memoria", che ora sono implementati qui.
- Con proposte e sintesi automatiche spente, su un Mac da 16 GB i risultati arrivano solo quando li chiedi; chi vuole il comportamento di prima riaccende i due interruttori.
- Una domanda in Chiedi durante una trascrizione lunga, su un Mac sotto i 32 GB, aspetta la fine della trascrizione.
- Un blocco interrotto si rifà: in caso di molte domande di fila una sintesi in sottofondo richiede più tempo.

## Precisazione del 2026-10-27 (ricerca)
- La **ricerca per significato mentre si scrive** è interattiva ma **non interrompe**: aspetta la fine del blocco in corso e passa davanti al blocco successivo. Interrompere a ogni tasto farebbe ripartire di continuo una sintesi in sottofondo. Chiedi e *Riordina testo* invece interrompono subito.
