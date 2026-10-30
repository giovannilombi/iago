# ADR-0076 — Modalità Traccia semplice, Inbox ed Elementi

- Stato: accettato (1.2.0-beta)
- Data: 2026-10-29
- Riferimenti: ADR-0074 (lavoro aperto, Traccia e Gestisci), ADR-0075 (viste); discussione con l'utente del 2026-10-29 su quattro versioni di una proposta con le finestre di esempio

## Contesto
- Nella prova della 1.1.0-beta, Traccia e Gestisci differivano per pochi stati e qualche campo: la complessità era quasi la stessa.
- La Kanban di tutti lasciava fuori i progetti in Traccia, e questo è risultato assurdo.
- «Traccia» e «Gestisci» da soli non dicevano che fossero modalità, né quale fosse la semplice.
- «Da fare» non era riconoscibile come il posto del lavoro che aspetta l'utente.
- «Elenco» non diceva che lì ci sono le call, le email e i documenti del progetto.
- «＋ Aggiungi» sembrava servire solo a scrivere punti chiave.

## Decisione
- **La modalità decide quanto si vede dentro un progetto, mai cosa esiste.**
  - Tutti i tipi di punto chiave ci sono in entrambe le modalità.
  - Inbox, Punti chiave e la Kanban di tutti contengono il lavoro di ogni progetto, in qualsiasi modalità; ogni voce si mostra nella modalità del suo progetto.
- **Nomi:** **Modalità Traccia** («semplice e veloce») e **Modalità Gestisci** («completa»).
  - Ognuna ha un'icona (`book.closed`, `rectangle.split.3x1`) e un colore (verde e blu).
  - La pillola accanto al nome del progetto apre le due modalità spiegate.
  - L'icona compare accanto a ogni progetto nella barra laterale.
- **Modalità Traccia:**
  - viste: Riepilogo breve, Elementi, Timeline e Grafo; niente Kanban e niente menu «Mostra»;
  - il Grafo ha un interruttore nella pillola, acceso di default;
  - un'attività è una casella da spuntare, con chi, entro quando, «in attesa di» e checklist (sempre presenti, senza interruttori);
  - punti da chiarire, rischi e richieste si scrivono e si chiudono con l'esito;
  - gravità, «diventato problema» e «nata da» sono solo in Gestisci; se già compilati restano salvati e un'icona lo dice.
- **Modalità Gestisci:** tutto, senza limiti. Resta la modalità predefinita.
- **Riepilogo breve** (in Traccia): una colonna con tre blocchi, «Da fare», «Da tenere d'occhio» e «Ultime decisioni e tappe». Un blocco vuoto non compare.
- **Finestra alla prima visita** di un progetto: dice la modalità e cosa offre ciascuna, e un clic cambia modalità.
  - «OK» la richiude e la finestra torna la volta dopo; «Non mostrare più» la toglie per quel progetto.
  - Su un cliente sceglie la modalità dei suoi progetti nuovi e di quelli a cui l'utente non l'ha scelta.
- **Inbox:** prende il posto di «Da fare». È in cima alla barra laterale, in grassetto, separata da una linea, con un bollino rosso che conta le voci dell'utente in ritardo o di oggi e le proposte da confermare.
  - «Da classificare» diventa **«Elementi da classificare»**, subito sotto, con l'icona `questionmark.folder`.
- **Barra delle viste:** `[Riepilogo] [Elementi] │ [Timeline · Kanban · Grafo]`, tutte con un'icona.
  - **Elementi** (prima «Elenco») mostra solo gli elementi.
  - «Mostra» vale per Timeline e Grafo, con le voci Tutto, Elementi e Punti chiave.
  - **Mappa torna Grafo.**
- **«＋ Aggiungi»** finisce con «Importa file ed elementi…». Apre una finestra con:
  - un'area dove trascinare i file e «Scegli dal Mac…»;
  - Dagli appunti, Da testo (si apre il campo per scrivere) ed Email senza file;
  - la destinazione, cioè il progetto e i suoi stream.

  Ciò che si importa va in quel progetto, non in «Elementi da classificare».

## Conseguenze
- Sostituisce, di ADR-0074:
  - gli stati di Traccia (Aperta, In attesa, Fatta, Annullata), che diventano la casella e gli esiti;
  - l'esclusione dei progetti in Traccia dalla Kanban di tutti.

  Di ADR-0075 sostituisce l'Elenco con «Mostra», l'elenco misto e il nome Mappa.
- Nessuna migrazione dei dati.
- Nelle impostazioni dell'archivio, perché passino con il backup: la modalità di un cliente per i progetti nuovi (`work.clientMode.<id>`) e i progetti con una modalità scelta a mano (`work.modeChosen`).
- In `UserDefaults`, solo preferenze di visualizzazione di quel Mac: l'interruttore del Grafo per progetto (`work.graphHidden`) e le finestre già chiuse per sempre (`work.modeIntro.dismissed`).
- Tolta `Archive.trackedProjectIDs()`.
- Il tour dimostrativo non mostra le finestre della prima visita: le mostra lui. A fine giro si chiude con `exit(0)`, perché `terminate` lasciava l'app aperta.

## Modifica del 2026-10-30 (1.2.4-beta)
- **Due bollini al posto di uno.** Un solo numero che sommava scadenze e proposte non si ritrovava nell'Inbox: 38 proposte stavano in una riga con un link a Punti chiave.
  - **Rosso, con «!» (Da fare ora):** ciò che chiede un'azione, tranne le proposte. Le voci dell'utente in ritardo o di oggi, quelle senza responsabile, le attese scadute (`OpenWork.needsAction`).
  - **Giallo, con la stellina (Proposte da confermare):** le proposte di punti chiave in attesa.
- **L'Inbox in tre blocchi**, ognuno con il suo numero nell'intestazione, dello stesso colore e con lo stesso segno del bollino (`InboxBlockHeader`, `InboxCountBadge`):
  - **Da fare ora:** in ritardo, oggi, senza responsabile, attese scadute;
  - **Proposte da confermare:** tutte, per elemento di origine, tre per elemento e poi «Mostra le altre»; si confermano, modificano e scartano lì, anche tutte insieme («Scarta queste», «Scarta tutte…»);
  - **Più avanti**, senza bollino: questa settimana, dopo, senza data, attese non scadute, checklist fissate.
- Ogni unità di un bollino è una riga visibile nell'Inbox. Punti chiave conserva il suo blocco «Da confermare».
