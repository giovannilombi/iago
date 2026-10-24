# ADR-0061 — Guida integrata, tour di benvenuto e archivio dimostrativo

- Stato: accettato
- Data: 2026-10-21
- Riferimenti: memoria "pre-distribuzione"; CLAUDE.md › Regole; richieste dell'utente 2026-10-21

## Contesto
L'app va usata da altri senza accompagnamento. Serve una guida completa, sempre aggiornata, con immagini che non mostrino dati reali.

## Decisione
- **La guida:**
  - capitoli Markdown in `App/Resources/Guide/NN-nome.md`, con le immagini in `Guide/img`, inclusi nel bundle come cartella;
  - la finestra **Guida di IAGO** li mostra a tutta pagina, con indice, ricerca e "precedente/successivo";
  - si apre da **? Guida** (in alto a sinistra, accanto alle Impostazioni), dal menu dell'icona di IAGO e da Impostazioni › Aiuto;
  - il segnaposto `{{icona}}` mostra nel testo l'icona vera della barra dei menu.
- **Il tour di benvenuto:**
  - 7 schermate: memoria del lavoro, registrare, importare, decisioni e momenti, sintesi, Chiedi, dati sotto il tuo controllo;
  - all'avvio finché l'utente non sceglie "Non mostrare più";
  - si rivede dalla guida e da Impostazioni › Aiuto.
- **Linguaggio:** si dice "icona di IAGO", e la prima volta "il nostro pappagallo con la memoria di ferro". Il concetto centrale è la memoria interrogabile (ADR-0058).
- **Archivio dimostrativo**, solo nella build Debug:
  - `-IAGODemoRoot <cartella>` apre un archivio separato e lo riempie con dati inventati;
  - `-IAGODemoTour <cartella>` porta la finestra nelle schermate della guida e aspetta ogni screenshot (`screencapture -l`).
- **Regola:** la guida si aggiorna a ogni modifica visibile all'utente, insieme a README e `docs/prove-tester.md`.

## Conseguenze
- Guida e README condividono i capitoli: il README li elenca con un link.
- Ogni nuova schermata importante si aggiunge al giro dimostrativo.
