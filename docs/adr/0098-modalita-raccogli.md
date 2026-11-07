# ADR-0098 — Modalità Raccogli: un archivio da interrogare, senza gestione

- Stato: accettato
- Data: 2026-11-07
- Modifica: ADR-0074 e ADR-0076 (modalità Traccia e Gestisci), ADR-0087 (Inbox)
- Riferimenti: ADR-0054 (sintesi), ADR-0069 (memoria del Mac), ADR-0072 (segnalibri con screenshot); richiesta dell'utente del 2026-11-07, approvata su un'anteprima

## Contesto
- Alcuni progetti sono solo una raccolta di materiali da cercare e interrogare, anche con Claude: interviste, focus group, archivi di gare, ricerche. Contengono audio, PDF, email e documenti con le loro trascrizioni e i loro testi.
- Per questi progetti la parte di gestione è rumore: punti chiave, Riepilogo, Kanban, Grafo e lavoro aperto nell'Inbox. Anche *Modalità Traccia*, la più semplice, la contiene.

## Decisione
- **Una terza modalità, la più semplice: Modalità Raccogli** (`WorkMode.collect`). Si sceglie come le altre dalla pillola accanto al nome del progetto, dall'icona nella barra laterale, in Impostazioni › Progetti o per i progetti nuovi di un cliente. Icona: una scatola d'archivio arancione. Nella finestra di scelta viene per prima: Raccogli, Traccia, Gestisci.
- **Cosa resta:**
  - le viste *Elementi* e *Timeline*, con i filtri;
  - trascrizioni, testi estratti, sintesi;
  - **segnalibri e schermate**, nella loro sezione e nella trascrizione;
  - **proposte** di nomi degli speaker, tag, progetto e collegamenti;
  - ricerca, *Chiedi a IAGO* (com'è oggi) e Claude;
  - tag, categorie, persone e voci.
- **Cosa non c'è:**
  - **viste:** Riepilogo, Kanban, Grafo e il menu *Mostra*; la timeline mostra solo gli elementi;
  - **punti chiave:** né nel menu *Aggiungi*, né nella scheda dell'elemento, né accanto ai segnalibri (*Diventa decisione…*);
  - **proposte di punti chiave:** il motore non le cerca e la scheda non le mostra (`SuggestionEngine.Input.keyPoints`). Claude non può scriverne: lo strumento lo dice e indica come cambiare modalità.
- **Inbox:**
  - il lavoro aperto dei progetti in Raccogli non c'è;
  - le loro **proposte** sì (nomi, tag, progetto, collegamenti), perché sono piccole conferme da non perdere (`Archive.pendingInboxSuggestions`);
  - una riga discreta lo spiega: «Dai progetti in Modalità Raccogli qui arrivano solo le proposte da confermare».
- **Sintesi:** su un Mac con **16 GB o meno** le sintesi automatiche saltano i progetti in Raccogli (`IntelligenceService.summarizesByItself`): si fanno con *Genera sintesi* o con Claude. Un archivio può avere molte registrazioni, e ogni sintesi occupa il Mac per minuti. Sopra i 16 GB valgono le impostazioni.
- **Nessun dato si perde:**
  - i punti chiave scritti prima restano salvati e tornano visibili passando a Traccia o Gestisci;
  - restano visibili anche in *Punti chiave* e nella Kanban di tutti, che mostrano ogni progetto;
  - la modalità è già un testo nel progetto, quindi non serve una migrazione.

## Conseguenze
- Un progetto-archivio si legge e si interroga senza strumenti di gestione, e su un Mac piccolo non lo appesantisce.
- **Tornare indietro:** una versione precedente di IAGO non sa leggere un progetto in Raccogli. Prima di tornarci, i progetti vanno rimessi in Traccia o Gestisci; il backup fatto prima di aggiornare resta il modo sicuro (README › Tornare a una versione precedente).
- Guida, tour e schermate presentano tre modalità.
