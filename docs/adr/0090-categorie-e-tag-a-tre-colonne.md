# ADR-0090 — Categorie e tag a tre colonne

- Stato: accettato
- Data: 2026-11-05
- Riferimenti: ADR-0054 (sintesi per categoria), ADR-0063 (barra laterale e accesso trasversale), ADR-0087 (colonne per sezione); richiesta dell'utente del 2026-11-05 (variante B)

## Contesto
- *Categorie e tag* mostrava le etichette e gli elementi in un'unica colonna, con il dettaglio nel pannello di destra della vista larga: con molti tag l'elenco si allungava e restava poco spazio per gli elementi.
- Si poteva filtrare per una sola etichetta alla volta. Per trovare, per esempio, le call di una categoria con due tag precisi bisognava scorrere a mano.

## Decisione
- **Tre colonne**, come nella variante B mostrata all'utente:
  - **a sinistra le etichette**, in due riquadri che si chiudono: *Categorie* e *Tag*. I tag sono ordinati per uso e hanno un campo di ricerca: Invio aggiunge il primo che corrisponde. I tag scelti compaiono come tessere blu con la ✕ per toglierli, e *Azzera* toglie tutto. Con il tasto destro un tag si fissa in alto, in *In evidenza*;
  - **al centro l'elenco** degli elementi, con un'intestazione che dice cosa si sta filtrando;
  - **a destra il dettaglio** dell'elemento scelto.
- **Filtro combinato:** una categoria e ogni tag scelto valgono insieme, in AND (`Archive.summaries(categoryID:tagIDs:)`). Senza nessuna scelta l'elenco mostra gli elementi che hanno almeno una categoria o un tag.
- **Larghezze:** due maniglie tra le colonne si trascinano e un doppio clic le riporta alla misura di base. Le misure restano tra un avvio e l'altro (`labels.width.labels`, `labels.width.list`), come i riquadri aperti o chiusi (`labels.categoriesOpen`, `labels.tagsOpen`). La colonna delle etichette va da 200 a 420 punti, l'elenco ha almeno 240 punti e il dettaglio almeno 360.
- Nella vista larga *Categorie e tag* non mostra il pannello di destra delle altre sezioni: il dettaglio è già la terza colonna.

## Conseguenze
- Le preferenze di questa vista non si leggono né si scrivono nel tour dimostrativo, così le schermate della guida sono sempre uguali.
- Nessun cambio allo schema dei dati: il filtro usa `item_tag` e `category_id` già esistenti.
