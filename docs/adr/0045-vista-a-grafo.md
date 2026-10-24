# ADR-0045 — Vista a grafo

- Stato: accettato
- Data: 2026-10-15
- Riferimenti spec: sez. 3.17 (FR-160…165), 10.5; ADR-0015

## Contesto
La spec chiede una vista nativa delle relazioni tra progetti, elementi, persone, organizzazioni, argomenti, tag e decisioni. Le note sono nodi facoltativi. La vista deve partire centrata sull'elemento selezionato, espandere i nodi con il doppio clic, filtrare per tipo, avere un cursore temporale e restare fluida fino a 500 nodi. La spec chiede di valutare la libreria Grape oppure un layout fatto in casa con `Canvas`.

## Decisione
- **Nessuna tabella e nessuna dipendenza nuova.**
  - I modelli `GraphNode`, `GraphEdge` e `Graph` stanno in `IAGOCore`.
  - La proiezione `GraphBuilder` sta in `IAGOIntelligence`. Legge le tabelle esistenti in un'unica lettura del database.
  - Il layout force-directed è nostro e il disegno usa SwiftUI `Canvas`. Per 500 nodi basta un calcolo delle repulsioni O(n²) su un thread in background, quindi Grape non serve: niente dipendenza da verificare e mantenere.
- **Nodi:**
  - progetto, cliente (fa da "organizzazione"), call, email, documento, persona, tag e decisione;
  - nota, nascosta di default;
  - gli "argomenti" arriveranno con l'estrazione del motore locale.
- **Persone:**
  - le persone registrate, cioè entità e contatti;
  - gli speaker con un nome, esclusi Io, Speaker N e Stanza;
  - i mittenti e destinatari delle email, riconosciuti dal contatto con la stessa email, altrimenti dall'indirizzo;
  - gli indirizzi dell'utente sono esclusi, altrimenti diventerebbero il centro di tutto.
- **Archi:**
  - elemento → progetto, progetto → cliente;
  - elemento ↔ tag ed elemento ↔ persona;
  - collegamenti tra elementi;
  - decisione → progetto, → fonte, → persone, → tag;
  - decisione → decisione che supera;
  - nota → elemento o progetto.
- **Forme e colori diversi per tipo** (FR-162):

  | Tipo | Forma | Colore |
  |---|---|---|
  | Progetto | quadrato arrotondato | blu |
  | Cliente | quadrato | colore del cliente |
  | Call | cerchio | viola |
  | Email | rombo | indaco |
  | Documento | rettangolo | verde acqua |
  | Persona | cerchio vuoto | arancione |
  | Tag | esagono | grigio |
  | Decisione | stella | verde |
  | Nota | quadratino | giallo |
- **Modalità:**
  - **Centrata** (default, quando c'è un elemento selezionato): l'elemento e i suoi vicini a profondità 1; il doppio clic su un nodo aggiunge i suoi vicini;
  - **Tutto l'ambito**: progetto, cliente o stream della barra laterale.
  - **Oltre 500 nodi:** si tolgono prima le note, poi gli elementi più vecchi vengono raggruppati per mese in un nodo "N elementi · mese".
- **Cursore temporale** (FR-163): mostra il grafo com'era fino a una data. Elementi, decisioni e note successivi spariscono.
- **Clic su un nodo:**
  - elemento, decisione o nota: si apre nel pannello di destra, come nelle altre viste;
  - persona, tag, progetto o cliente: scheda breve nel grafo, con "Apri" verso la vista corrispondente.
- **Navigazione:** trascinamento per spostare la vista o un singolo nodo, zoom con pizzico o rotella.

## Conseguenze
- Il grafo è sempre coerente con l'archivio, perché viene ricalcolato a ogni modifica.
- La qualità del layout è sufficiente per questo uso, ma non quella di una libreria specializzata. Se servisse si può rivalutare Grape senza cambiare la proiezione.
