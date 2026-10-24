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
| `list_projects`, `project_timeline`, `search`, `get_item`, `get_thread`, `list_decisions`, `list_notes`, `find_file`, `export_project` | `add_note`, `update_note`, `add_decision`, `update_decision`, `add_email`, `create_document`, `import_file`, `write_batch` |

## Scritture (ADR-0044, ADR-0047)
1. Ogni strumento di scrittura funziona **in due passi**: senza `confirmation` restituisce solo un'**anteprima** (cosa, dove, a cosa è collegato, quale voce supera).
2. Claude la mostra all'utente; solo con la conferma richiama lo strumento e la scrittura avviene.
3. Le scritture arrivano all'app attraverso una casella (`MCPInbox`), così l'app le applica nel suo processo e aggiorna l'interfaccia.
4. Ogni scrittura si può **annullare** e porta il segno "via Claude".

## Collegare Claude
In **Impostazioni › Claude** IAGO prepara la configurazione per Claude Desktop o il comando per Claude Code, con un nome per la connessione e il progetto (o i progetti) da esporre. Le istruzioni per l'utente sono nel capitolo [Claude](/guida/claude) della guida.

::: warning Dove vanno i dati
Quello che Claude legge arriva ad Anthropic secondo le condizioni dell'account Claude dell'utente. Per questo è spento di default e si abilita progetto per progetto (ADR-0058).
:::
