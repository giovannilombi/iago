# ADR-0081 — Introduzione all'uso

- Stato: accettato (1.2.9-beta)
- Data: 2026-10-30
- Riferimenti: ADR-0066 (l'app non contiene contenuti), ADR-0068 (guida e sito), ADR-0077 (italiano e inglese); richiesta dell'utente del 2026-10-15, ripresa il 2026-10-30

## Contesto
- Prima di distribuire IAGO serve un'introduzione che insegni a usarlo, oltre alla configurazione del primo avvio.
- Il tour di benvenuto aveva sette schede di solo testo: non mostrava l'app, non faceva provare niente e non parlava di importazione, viste del progetto e Claude.

## Decisione
- **Introduzione** al posto del tour, con la frase *«IAGO, sempre sulla tua spalla. Riunione dopo riunione.»*: dieci passi obbligatori, ognuno con la schermata vera dell'app e un pulsante che porta in quel punto:
  1. la memoria del lavoro; 2. le riunioni riconosciute, la registrazione e il pannello dopo lo Stop; 3. l'importazione; 4. trascrizione, nomi e sintesi; 5. Riepilogo, Timeline, Kanban e Grafo; 6. l'Inbox; 7. decisioni e attività con la fonte; 8. Chiedi a IAGO; 9. Claude sui progetti scelti; 10. dati e scelte.
- **Primi passi**, a lato: registrare una call, importare un'email o un documento, dare un nome a uno speaker, mettere un elemento in un progetto, confermare una proposta, fare una domanda. Si spuntano da soli leggendo l'archivio (`Archive.firstSteps`); collegare Claude è facoltativo e non conta.
- Compare dopo la configurazione del primo avvio e a ogni avvio, finché l'utente non sceglie *Non mostrare più* o completa i primi passi. Si riapre da Aiuto (capitolo Primi passi) e da Impostazioni › Aiuto.
- Le schermate sono quelle della guida, rifatte dal tour dimostrativo in italiano e inglese: aggiornare la guida aggiorna anche l'introduzione. Il tour aggiunge *grafo*, *dopo-stop* e *claude*.
- «Apri il progetto di esempio» apre il progetto principale dei progetti di esempio (ADR-0066, modifica del 2026-10-31), gli stessi delle schermate.

## Conseguenze
- Va aggiornata fino alla distribuzione, insieme alla guida (`docs/stato.md`).
