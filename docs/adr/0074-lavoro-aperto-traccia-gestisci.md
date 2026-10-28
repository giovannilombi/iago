# ADR-0074 — Lavoro aperto e due modalità: Traccia e Gestisci

- Stato: proposto
- Data: 2026-10-28
- Riferimenti: ADR-0014 (modello `decision` con `kind`), ADR-0046 (punti chiave), ADR-0049 (proposte), ADR-0052 (superamenti multipli), ADR-0071 (Claude); progetto [`docs/design/lavoro-aperto.md`](../design/lavoro-aperto.md); discussione con l'utente del 2026-10-27 e 2026-10-28

## Contesto
- IAGO è usato da operativi e da PM. I punti chiave (decisione, attività, tappa) registrano bene cosa è successo, ma non dicono **cosa è aperto, di chi è, per quando, cosa blocca**.
- Servono punti da chiarire, rischi, richieste del cliente, attese da altri e checklist che non si perdano nella timeline.
- Non si vuole complicare l'uso per chi non gestisce progetti, né togliere funzioni a chi li gestisce.

## Decisione
- **Tutti i tipi ci sono sempre.**
  - **Memoria:** decisione e tappa.
  - **Lavoro:** attività, con checklist; punto da chiarire; rischio, con gravità e «diventato problema»; richiesta.
- **Due modalità sugli stessi dati**, scelte per persona, con eccezioni per progetto:
  - **Traccia** (predefinita): stati Aperta, In attesa, Fatta, Annullata; campi base (responsabile, scadenza, in attesa di, checklist); viste Timeline, Punti chiave, Da fare, Riepilogo breve, Grafo;
  - **Gestisci**: anche In corso e Bloccata, priorità, dipendenze, stima, inizio, ricorrenza, kanban di progetto e globale con colonne libere, riepilogo completo con sintesi di stato.

  Passare da una modalità all'altra non perde dati.
- **Tre legami:**
  - **supera / chiude:** quello di ADR-0052, letto con il verbo adatto: sostituisce, risponde a, accoglie, completa;
  - **nata da;**
  - **dipende da.**
- **Chiusure con esito:** la risposta a un punto da chiarire; una richiesta accolta, rifiutata con il motivo o trasformata; un rischio risolto o non più rilevante.
- **Timeline:** chiudere non aggiunge righe, cambia solo l'aspetto.
  - Fatta: ✓, non barrata.
  - Superata o annullata: barrata, come oggi.
  - Chiusa da un'altra voce dello stesso giorno: annidata sotto di lei.
- **Proposte** del motore e di Claude per tutti i tipi, sempre da confermare.
- **Dati:** migrazione additiva `v21-work` (dettaglio nel progetto). `kind` e `status` sono testo: le voci di oggi non si convertono.
- **Prove su una copia dell'archivio** (`scripts/try-branch.sh`) e sviluppo sul branch `feat/lavoro` fino all'approvazione.
- **Fuori, per ora:** sincronizzazione con i calendari (in attesa, richiederà un ADR di rete), Pianifica la giornata, invio di attività ad altri prima della fase 4, sprint e calcolo delle stime.

## Conseguenze
- Chi tiene solo traccia vede IAGO quasi com'è oggi, con in più l'inbox Da fare e il riepilogo breve. Chi gestisce ha gli strumenti senza un secondo programma.
- ADR-0046 viene esteso (tipi e stati nuovi); ADR-0052 resta valido e il suo legame diventa «supera / chiude».
- MCP, esportazioni, grafo, guida, tour e prove per i tester vanno aggiornati in ogni fase.
