# ADR-0086 — Stile: colore come segnale, chiaro e scuro

- Stato: accettato (1.2.13-beta)
- Data: 2026-11-02
- Riferimenti: ADR-0084 (dettaglio dell'elemento), ADR-0085 (Riepilogo a box); proposte approvate dall'utente sui prototipi del 2026-11-02

## Contesto
- Ogni tipo di punto chiave aveva il suo colore ovunque: titoli dei box, etichette delle tile, icone delle righe, sfondo e bordo delle schede, etichetta del progetto. Sei o sette colori nella stessa schermata, un effetto «arlecchino».
- Il foglio di un punto chiave nuovo mostrava di nuovo tutti e sei i tipi come pillole colorate, anche se l'utente li aveva appena scelti dal menu.
- In chiaro le pagine erano quasi tutte bianche, e il titolo di un box si confondeva con la sua prima riga.
- Non si poteva scegliere chiaro o scuro dentro IAGO.

## Decisione
- **Colore come segnale (stile A):**
  - testi neutri, compresi titoli ed etichette;
  - il colore del tipo resta nella barretta a sinistra e nell'icona del box, nel puntino delle tile e dei menu, e nell'icona sulla linea della timeline;
  - righe, schede della Kanban e della timeline hanno fondo neutro e icone grigie; il **rosso** solo per ciò che chiede attenzione (scaduto, bloccato, rischio alto); il **blu** per ciò che si clicca e per la selezione;
  - barra laterale con icone grigie; restano colorati i bollini dell'Inbox, i quadratini dei clienti e l'icona della modalità.
- **Titolo dei box (T2):** un filo da bordo a bordo separa titolo e contenuto, appena più chiaro del box in scuro e appena più scuro in chiaro, mai colorato. L'Inbox tiene le sue lineette rossa e gialla.
- **Foglio «Aggiungi»:** il titolo è «Aggiungi», come il pulsante premuto (o «Modifica»), seguito dal tipo in una tile; un clic sulla tile apre i sei tipi con una riga di spiegazione. Il menu «Aggiungi» ha il puntino del tipo e separa decisioni e tappe dal lavoro aperto.
- **Trascrizione (M2):** segnalibri e schermate su un velo leggero del loro colore con un filo a sinistra; testo normale, miniatura per le schermate.
- **Kanban (K3):** colonne in box, un poco più scure della finestra, con la riga del colore dello stato sotto il titolo; schede con un bordo marcato.
- **Attività (A2):** una colonna centrata, con *Ultimi 7 giorni* e *Pronto per lavorare* affiancati in alto. **Categorie e tag** a tutta finestra.
- **Aspetto:** un menu accanto alle Impostazioni, con *Automatico* (come il Mac, predefinito), *Chiaro* e *Scuro*.
- **Chiaro senza bianco pieno (grigio freddo):** pagine #EDEFF2, box #F8F9FB, barre in alto #E6E9ED, barra laterale velata e più scura delle pagine. In scuro restano i colori del sistema.

## Conseguenze
- I colori sono definiti in un punto solo (`IAGOColor`, `AppAppearance.swift`) e si adattano all'aspetto da soli.
- Le schermate della guida si rifanno quando la grafica è stabile, con `scripts/guide-screenshots.sh`.
- I campi di testo e i fogli meno usati restano del sistema.
