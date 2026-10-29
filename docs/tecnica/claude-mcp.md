# Claude e MCP

IAGO si può collegare a **Claude Desktop** o **Claude Code** con il Model Context Protocol, per ragionare sui progetti con un modello più potente. È facoltativo e si decide progetto per progetto.

## Il server (ADR-0010, ADR-0043)
- Eseguibile `iago-mcp` nel bundle dell'app (`Contents/MacOS`), pacchetto `IAGOMCP`.
- **Solo stdio:** Claude lo avvia come processo; nessuna porta di rete aperta.
- Legge lo stesso archivio dell'app; una chiave per il server viene preparata dall'app all'avvio.
- **Visibilità per progetto:** flag "Consultabile da Claude" (spento di default) e, separato, "Claude può scrivere". Gli elementi senza progetto non sono mai visibili.
- Ogni chiamata finisce nel **registro accessi**.

## Strumenti
| Lettura | Scrittura (con anteprima) |
|---|---|
| `list_projects`, `recent_items`, `project_timeline`, `search`, `get_item`, `get_thread`, `list_decisions`, `list_notes`, `summary_template`, `get_screenshots`, `find_file`, `export_project` | `add_note`, `update_note`, `add_decision`, `update_decision`, `add_email`, `create_document`, `import_file`, `write_batch`, `set_summary`, `propose_suggestions` |

**Lavoro aperto (ADR-0074).**
- `list_decisions` filtra per i sei tipi (o `work`), per gli stati nuovi (o `open`) e per `owner`, e mostra `decision_id`, responsabile, scadenza, attese, priorità, dipendenze, checklist ed esito.
- `add_decision` e `update_decision` accettano `kind`, `status`, `owner`, `waiting_on`, `due`, `waiting_until`, `starts_at`, `happened_at`, `priority`, `estimate`, `severity`, `recurrence`, `derived_from_id`, `blocked_by_ids`, `checklist`, e in modifica `outcome_kind` e `outcome`.
- Le persone nuove si creano solo alla conferma; l'anteprima segnala i nomi simili («Intendi …?»).
- L'annullamento rimette anche questi campi, le dipendenze e la checklist.

## Sintesi e proposte fatte da Claude (ADR-0071)
- **Trovare l'elemento:** «Copia per Claude» nella scheda copia `item_id` e la richiesta; senza, `recent_items` elenca gli ultimi elementi di tutti i progetti consultabili.
- **`set_summary`:** Claude manda sezioni e punti con la **citazione esatta**; IAGO li compone con `SummaryGenerator.compose`, nel modello della categoria (`summary_template`), verificando ogni citazione con `KeyPointExtractor.locate` come per il motore locale. I punti senza citazione, con una citazione che non trova, o in una sezione che il modello non ha, vengono scartati e riportati nell'anteprima. I punti letti su una schermata usano `screenshot_at` e restano solo se la call ha una schermata entro 5 secondi da quel minuto.
- **`propose_suggestions`:** decisioni, attività, punti da chiarire, rischi e richieste (con citazione verificata, e `owner`, `due`, `waiting_on`, `severity`, `closes`) e tag diventano `suggestion` con `origin = claude`, in attesa di conferma. Il motore e Claude non cancellano le proposte in attesa l'uno dell'altro.
- La sintesi si salva con `origin = claude` e `model` = l'app da cui si usa Claude (`clientInfo` di `initialize`). «Rigenera» con il motore chiede conferma; la sintesi automatica salta gli elementi che ne hanno già una.
- Entrambe finiscono in `mcp_change` (`summary`, `suggestion`) e si annullano da Impostazioni › Claude: la sintesi precedente torna com'era, le proposte ancora in attesa spariscono. Una sintesi riscritta dopo (da Claude, dal motore o a mano) non si annulla: IAGO lo spiega invece di perdere quel lavoro. La sintesi automatica, prima di salvare, ricontrolla che nel frattempo non sia arrivata una sintesi di Claude o una modifica a mano.

## Schermate (ADR-0072)
- `get_item` include il **testo** delle schermate al loro minuto.
- `get_screenshots` restituisce le **immagini** come contenuto MCP `image` (JPEG, lato lungo 1.568 pixel, al massimo 8 per chiamata), solo se l'utente attiva «Condividi con Claude anche le immagini delle schermate» (`claude.share_screenshots`, spento di default).

## Scritture (ADR-0044, ADR-0047)
1. Ogni strumento di scrittura funziona **in due passi**: senza `confirmation` restituisce solo un'**anteprima** (cosa, dove, a cosa è collegato, quale voce supera).
2. Claude la mostra all'utente; solo con la conferma richiama lo strumento e la scrittura avviene.
3. Il server scrive direttamente nell'archivio con una connessione di scrittura aperta alla prima scrittura; solo audio, video e trascrizioni di Teams passano dalla casella dell'app (`MCPInbox`), che li converte e li trascrive come un trascinamento.
4. Ogni scrittura si può **annullare** e porta il segno "via Claude".

## Collegare Claude
In **Impostazioni › Claude** IAGO prepara la configurazione per Claude Desktop o il comando per Claude Code, con un nome per la connessione e il progetto (o i progetti) da esporre. Le istruzioni per l'utente sono nel capitolo [Claude](/guida/claude) della guida.

::: warning Dove vanno i dati
Quello che Claude legge arriva ad Anthropic secondo le condizioni dell'account Claude dell'utente. Per questo è spento di default e si abilita progetto per progetto (ADR-0058).
:::
