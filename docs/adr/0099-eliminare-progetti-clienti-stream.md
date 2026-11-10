# ADR-0099 — Eliminare progetti, clienti e stream: Cestino o eliminazione definitiva

- Stato: accettato
- Data: 2026-11-10
- Modifica: ADR-0030 (Cestino, ora anche per i progetti), ADR-0038 (eliminazione di clienti e stream: stesse regole, conferme più chiare)
- Riferimenti: ADR-0039 (chiavi dei progetti), ADR-0044 (Claude); richiesta dell'utente del 2026-11-10

## Contesto
- Clienti e stream si eliminavano con il tasto destro nella barra laterale; un progetto solo da Impostazioni › Progetti, e solo per sempre (avviso, DELETE, ultima conferma).
- Eliminando un cliente, i suoi progetti passavano senza avviso in «Senza cliente»; eliminando uno stream non si sapeva quanti elementi lo usavano.
- Un progetto eliminato per errore non si poteva recuperare.

## Decisione
- **Progetto, dal tasto destro (*Elimina progetto…*) e da Impostazioni, con lo stesso dialogo:**
  - dice cosa contiene (elementi, trascrizioni, note) ed **elenca gli stream** che se ne vanno con lui;
  - fa scegliere, spiegando la differenza:
    - **Sposta nel Cestino** (scelta predefinita): basta una conferma, perché si può tornare indietro. Il progetto sparisce da barra laterale, menu dei progetti, ricerca, Inbox, Punti chiave, grafo e Claude, ma resta sul Mac. Si ripristina dal Cestino per **30 giorni**, poi si elimina da solo per sempre. Anche *Svuota cestino* lo elimina;
    - **Elimina definitivamente**: il percorso di prima, cioè scrivere DELETE e poi l'ultima conferma.
- **Cliente:** una conferma che **elenca i suoi progetti, con i loro stream**. I progetti non si eliminano mai con il cliente: passano in «Senza cliente» con tutto il loro contenuto. L'utente ha scelto questa regola semplice al posto di scegliere, per ogni progetto, un altro cliente o l'eliminazione.
- **Stream:** una conferma che dice quanti elementi, punti chiave e note perdono l'etichetta. Non serve il Cestino, perché non si perde nessun contenuto.
- **Come è fatto:**
  - **migrazione `v25-project-trash`:** una colonna `project.trashed_at`, solo aggiunta;
  - **gli elementi** del progetto vanno nel Cestino con lui (`trash_reason` = `project`), così ogni query che esclude gli elementi nel Cestino esclude anche loro. Non compaiono uno per uno nel Cestino. Quelli che erano già nel Cestino restano lì con la loro data;
  - **note, punti chiave, checklist, stream e righe della ricerca** del progetto si escludono con `Archive.outsideTrashedProjects`;
  - **Claude** vede solo i progetti di `projects()`, che esclude quelli nel Cestino;
  - **casi particolari:**
    - un elemento ripristinato mentre il suo progetto è nel Cestino torna senza progetto, in «Elementi da classificare»;
    - un progetto ripristinato dopo l'eliminazione del suo cliente torna in «Senza cliente».

## Conseguenze
- Un progetto eliminato per errore si recupera per 30 giorni, così com'era.
- Nel Cestino un progetto occupa spazio sul Mac fino a quando non viene eliminato.
- **Tornare indietro:** una versione precedente ignora la colonna nuova e mostrerebbe come normali i progetti nel Cestino. Nessun dato si perde.
