# ADR-0087 — Inbox a due metà, proposte a destra, colonne per sezione

- Stato: accettato
- Data: 2026-11-03
- Riferimenti: ADR-0076 (Inbox in tre blocchi), ADR-0086 (stile); proposte approvate dall'utente sui prototipi del 2026-11-03 (V1, indicatore discreto; V3, proposte a destra)

## Contesto
- Nell'Inbox i blocchi stavano uno sotto l'altro in un solo scorrimento: con molte voci in *Da fare ora* le *Proposte da confermare* finivano in fondo e non si vedevano.
- Le proposte si confermavano nella colonna centrale, stretta, tre per elemento e poi «Mostra le altre»: scomodo.
- La larghezza della colonna centrale, una volta cambiata, valeva per tutte le sezioni.

## Decisione
- **Due box a metà altezza:** *Da fare ora* in alto, *Proposte da confermare* in basso. Ognuno ha la sua intestazione fissa (segno, titolo, bollino, lineetta rossa o gialla da bordo a bordo) e scorre per conto suo. Una maniglia tra i due ne cambia la parte (dal 20% all'80%), che resta salvata; un doppio clic torna a metà e metà.
- **Più avanti** e, con *Mostra chiuse*, le voci chiuse stanno in fondo al box *Da fare ora*, sotto un titolo grigio senza bollino.
- **Barra di scorrimento sempre visibile** quando sotto c'è altro, qualunque sia l'impostazione del Mac; sottile e tenue (senza binario, un po' più marcata sotto il puntatore). Sparisce quando tutto entra.
- **«altre N»** in basso a destra del box: discreto, tre puntini piccoli e tenui che si accendono una volta ogni 10 secondi (fermi con *Riduci movimento*), più il numero delle voci sotto l'ultima visibile. Sparisce in fondo alla lista.
- **Proposte per elemento:** nel box in basso, un box per elemento con tipo, titolo, data, progetto, quali proposte ha («Attività 2 · Rischio») e quante. Un clic lo evidenzia e apre a destra tutte le sue proposte, ognuna con frase, minuto, *Conferma*, *Modifica…* e *Scarta*; in alto *Apri l'elemento*, *Conferma tutte* e *Scarta queste*. Senza più proposte l'elemento esce dall'elenco.
- **Colonne per sezione:** la prima volta la colonna centrale e quella destra sono a metà. Se l'utente sposta il divisore, la larghezza resta salvata solo per quella sezione: Inbox, Elementi da classificare, Recenti, Non definito, Punti chiave, Importa, Cestino, Ricerca; progetti, clienti, stream, categorie e tag ne hanno una in comune per ogni vista (Elementi, Timeline, Punti chiave). Finché in una sezione non si sceglie, le colonne restano a metà anche quando la finestra cambia misura.
- **Box vuoto:** si riduce all'intestazione con una riga («Nessuna proposta da confermare.», «Niente in ritardo, per oggi o senza responsabile.») e l'altro prende tutto lo spazio. Se sono vuoti tutti e due resta «Niente da fare».

## Conseguenze
- `InboxBox`, `InboxSplit`, `InboxMorePill` e `ThinScroller` (`WorkShared.swift`) si possono riusare per altri elenchi a box; `ProposalItemCard` e `ItemProposalsPane` in `InboxProposals.swift`.
- `ContentColumnWidth` (`ColumnWidths.swift`) legge e muove il divisore della finestra (`NSSplitView`), misurando la colonna centrale dal bordo della barra laterale, che le sta sopra. Le larghezze sono in `columns.contentWidth`; il tour dimostrativo non le legge né le scrive.
- Le viste a tutta finestra (Riepilogo, Kanban, Grafo, Attività, Categorie e tag) non cambiano: il loro pannello a destra resta com'è.
- Il tour dimostrativo fa anche gli scatti di revisione `inbox-basso` (finestra bassa) e `inbox-proposte` (proposte aperte a destra), che non vanno nella guida.
