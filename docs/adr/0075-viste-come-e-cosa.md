# ADR-0075 — Viste di progetto: come guardare e cosa mostrare

- Stato: accettato (1.1.0-beta, in prova; aggiornato da [ADR-0076](0076-modalita-inbox-elementi.md))
- Data: 2026-10-28
- Riferimenti: ADR-0037 (timeline e registro), ADR-0045 (grafo), ADR-0074 (lavoro aperto, Traccia e Gestisci); discussione con l'utente del 2026-10-28 sulle alternative della barra delle viste (stile B2)

## Contesto
- Con la 1.1.0-beta la barra sopra la lista aveva sei pulsanti alla pari: Elenco, Timeline, Punti chiave, Grafo, Riepilogo, Kanban. Mescolava forme (elenco, timeline), contenuti (punti chiave) e pagine (riepilogo), senza una gerarchia.
- La Kanban nella colonna centrale era troppo stretta per essere usata.

## Decisione
- **Un progetto contiene una sola cosa, la sua storia** (call, email, documenti, note, punti chiave); le viste sono modi di guardarla. In alto, due scelte indipendenti:
  - **come guardare**, dalla forma più semplice alla più ricca: **Elenco**, **Timeline**, **Kanban**, **Mappa** (il grafo di prima);
  - **cosa mostrare**, menu «Mostra» a destra: **Tutto**, **Materiali** (call, email, documenti, note), **Punti chiave**.
- **Riepilogo** sta a parte, primo pulsante separato da una linea: è la pagina del progetto, non un modo di guardarlo.
- Le viste di prima diventano combinazioni: Elenco con Materiali è l'elenco di prima, Elenco con Punti chiave è la vista Punti chiave, Timeline con Tutto è la timeline, Mappa con Tutto è il grafo. Elenco con Tutto è nuovo: materiali, punti chiave e note in un solo elenco per data.
- La **Kanban** mostra solo il lavoro aperto («Mostra: Lavoro aperto», fisso) e c'è solo nei progetti in Gestisci.
- **Kanban, Riepilogo e Mappa sono larghe:** occupano lo spazio della lista e del dettaglio. Ciò che si apre da loro compare in un **pannello a destra**, chiuso con ✕ o Esc. Elenco e Timeline restano con il dettaglio a destra.
- **Il Riepilogo usa la larghezza:** una fascia di numeri su tutta la riga; sotto, due colonne di card (a sinistra ciò su cui agire, a destra cosa è cambiato, sintesi di stato e checklist), una sola colonna quando la finestra è stretta.
- **IAGO ricorda per ogni progetto, cliente, stream e luogo della libreria l'ultima combinazione.** La prima volta un progetto, un cliente o uno stream si aprono sul Riepilogo.
- «Punti chiave» e «Da fare» nella barra laterale hanno solo Elenco e Kanban (la Kanban di tutti è larga anch'essa).

## Conseguenze
- `AppModel.ViewMode` diventa `overview, list, timeline, board, map`, con `ViewContent` (`all, materials, keyPoints`) per «Mostra»; la scelta è salvata in `UserDefaults` (`views.byScope`), non nell'archivio.
- La finestra ha due disposizioni: tre colonne (sidebar, lista, dettaglio) e due colonne (sidebar, vista larga con il pannello a destra).
- Guida, tour dimostrativo e prove per i tester descrivono la barra nuova.
