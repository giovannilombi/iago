# ADR-0085 — Riepilogo a box, Traccia divisa in due, Attività a tutta finestra

- Stato: accettato (1.2.12-beta)
- Data: 2026-11-02
- Riferimenti: ADR-0055 (Attività), ADR-0075 (viste di progetto), ADR-0076 (Traccia e Gestisci), ADR-0084 (dettaglio dell'elemento: tile e sezioni vuote); proposte approvate dall'utente sul prototipo del 2026-11-02

## Contesto
- Il Riepilogo in *Modalità Gestisci* aveva in alto sei riquadri di numeri, con testi tagliati e senza a capo quando la finestra non è a tutto schermo. Sotto c'erano due colonne fisse con blocchi di altezze molto diverse, che lasciavano spazi vuoti.
- In Gestisci mancavano le ultime decisioni e tappe, che in Traccia ci sono.
- In *Modalità Traccia* il Riepilogo breve era una sola colonna al centro della finestra, che migliorava solo dopo aver aperto una voce.
- Attività mostrava a destra «Nessun elemento selezionato», ma lì non c'è niente da selezionare.

## Decisione
- **Gestisci, una pagina di box.**
  - I box, in ordine di importanza: *Da fare e scadenze*, *Da tenere d'occhio* (rischi per gravità e punti da chiarire), *Attese da altri*, *Ultime decisioni e tappe*, *Prossime tappe*, *Sintesi di stato*, *Cosa è cambiato*, *Checklist*, *Bloccate*.
  - Sono su due colonne "a muro": ognuno va nella colonna più corta, misurata con il suo contenuto vero. Sotto gli 860 punti, anche con il pannello a destra aperto, diventano una colonna.
  - In alto, sempre visibili, le **tile dei box**, come nel dettaglio dell'elemento: un dato per box. Un clic porta al box e lo fa brillare per mezzo secondo, anche se è già in vista.
  - Un box vuoto è ridotto alla sua intestazione tratteggiata, con la sua frase.
  - I conteggi per tipo e le barre di avanzamento escono dalla pagina: restano nelle righe, nella Kanban e nell'Inbox.
- **Traccia, pagina già divisa.** Il Riepilogo breve tiene il pannello a destra sempre aperto. Senza una voce aperta mostra il logo e «Nessun elemento selezionato», senza ✕.
- **Attività a tutta finestra.**
  - Niente colonna di dettaglio: *Apri* mostra l'elemento nel pannello a destra.
  - In alto le tile: In corso, In coda, Ultime 24 ore, Non riuscite. Le sezioni sono nello stile della scheda, ridotte all'intestazione quando sono vuote.
  - A destra, o sotto con la finestra stretta, *Ultimi 7 giorni* (call, email e documenti per giorno, più le trascrizioni fatte) e *Pronto per lavorare* (motore del Mac, spazio dell'archivio e dei modelli).
- **Barra laterale:** l'icona della modalità di un progetto ha sempre il suo colore, verde per Traccia e blu per Gestisci. Un clic apre la scelta della modalità, come la pillola accanto al nome.

## Conseguenze
- La pagina di Gestisci non ha più posizioni fisse: l'ordine dei box resta, la colonna dipende dalle altezze.
- Le schermate della guida di Riepilogo, Riepilogo breve e Attività vanno rifatte a ogni cambio di questi box.
