# ADR-0038 — Gerarchia Cliente › Progetto › Stream

- Stato: accettato
- Data: 2026-10-13
- Riferimenti spec: sez. 8.4 (progetto), FR-70, FR-153; richiesta utente

## Contesto
Alcuni clienti hanno più progetti attivi e alcuni progetti hanno più filoni di lavoro. La spec v1.4 prevede solo progetti piatti. L'utente ha scelto:
- un albero per cliente nella barra laterale;
- nessun elemento appeso direttamente al cliente;
- gli stream anche nella barra laterale;
- più stream per elemento.

## Decisione
- **Migrazione `v7-hierarchy`:**
  - tabella `client` (nome, colore, archiviato, colonne di sync);
  - colonna `project.client_id`, facoltativa;
  - tabella `stream` (`project_id`, nome, colore, ordine, archiviato, colonne di sync);
  - tabelle di collegamento `item_stream` e `decision_stream`, molti-a-molti.
- **Il cliente contiene solo progetti.** Eliminarlo lascia i progetti senza cliente.
- **Stream:**
  - Uno stream appartiene a un progetto. Un elemento o una decisione può stare in più stream del proprio progetto; quelli di altri progetti vengono ignorati.
  - Se un elemento o una decisione cambia progetto, perde gli stream del progetto precedente. La UI chiede conferma.
  - Eliminare uno stream toglie solo l'etichetta.
  - Eliminare un progetto elimina anche i suoi stream.
  - Una nuova decisione presa da un elemento eredita gli stream dell'elemento.
- **Ambiti:**
  - `LibraryScope`, `DecisionQuery.Scope` e `SearchScope` si estendono con cliente e stream.
  - Il cliente aggrega tutti i suoi progetti.
  - Lo stream filtra gli elementi e le decisioni che lo contengono.
  - La ricerca nello stream include anche le note degli elementi dello stream.
- **Barra laterale:**
  - in cima i progetti fissati, piatti, con il nome del cliente in piccolo;
  - poi i clienti, apribili, con i loro progetti, ciascuno con i propri stream apribili;
  - infine "Senza cliente".
  - Lo stato di apertura dei rami è salvato.
  - Un progetto si sposta in un cliente trascinandolo (testo con prefisso `iago-project:`, mai confuso con un file), dal menu contestuale o dalle Impostazioni.
- **Colori:** clienti e stream ricevono a turno un colore da una tavolozza fissa (`Archive.palette`).

## Conseguenze
- Le persone (Blocco 5) si definiranno sul cliente e varranno per tutti i suoi progetti.
- L'export (Blocco 6) e l'MCP (Fase 3) accetteranno come ambito un cliente, un progetto o uno stream.
