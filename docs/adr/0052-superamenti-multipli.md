# ADR-0052 — Superamenti multipli e tra tipi diversi

- Stato: accettato
- Data: 2026-10-20
- Riferimenti spec: FR-151; ADR-0037 (registro decisioni), ADR-0046 (punti chiave), ADR-0047; richiesta utente 2026-10-20

## Contesto
Un punto chiave (decisione, attività o tappa) oggi può superarne **uno solo** (`decision.supersedes_id`). Nella pratica una tappa come "Firmato il PX7 e inviata tutta la documentazione" chiude insieme una decisione e due tappe precedenti. Anche Claude si è fermato su questo limite. L'utente vuole che qualsiasi punto chiave possa superare **più voci di qualsiasi tipo**.

## Decisione
- **Legami:**
  - nuova tabella `decision_supersede (newer_id, older_id, created_at)`, migrazione `v16-supersede-links`;
  - una voce può superarne molte, ed essere superata da più voci;
  - qualsiasi tipo supera qualsiasi tipo;
  - i legami di oggi vengono copiati nella tabella. La colonna `supersedes_id` resta solo per le versioni precedenti dell'app e non viene più letta.
- **Stato:**
  - una voce è **Superata** se almeno una voce non annullata e non eliminata la supera;
  - quando l'ultima voce che la supera viene annullata, eliminata o scollegata, torna **Attiva**. Un'attività "Fatta" resta Fatta;
  - lo stato si ricalcola sulle voci toccate a ogni modifica.
- **Controlli:**
  - **niente cerchi**: una voce non può superare una voce che, direttamente o tramite altre, la supera già;
  - **cambio d'ordine, come oggi (ADR-0047)**: se la voce scelta viene già dopo, con conferma questa voce passa dopo di lei e chi la superava supera le sue precedenti;
  - **data precedente** a una delle voci superate: avviso, non blocco.
- **Interfaccia:**
  - **modifica:** "Supera" diventa una scelta multipla (etichette con ✕, più "Aggiungi…" con le voci attive, prima quelle del progetto);
  - **Evoluzione:** l'elenco di tutte le voci collegate in ordine di data. Per la voce aperta, "Supera: …" e "Superata da: …";
  - **nome della catena:** sta sulla voce più vecchia del gruppo collegato;
  - **timeline e Punti chiave:** una voce superata nello stesso giorno compare sotto la più recente che la supera;
  - **grafo ed esportazioni:** mostrano tutti i legami.
- **Claude (MCP):** `add_decision` e `update_decision` accettano `supersedes_ids` (elenco). `supersedes_id` resta valido, come elenco di uno. L'anteprima elenca tutte le voci che diventeranno superate, e l'annullamento rimette legami e stati com'erano.
- **Proposte del motore:** possono continuare a proporre una sola voce da superare. Confermandole, il legame va nella nuova tabella.

## Conseguenze
- Il registro rispecchia come vanno davvero le cose: una tappa o una decisione chiude più questioni insieme.
- La "catena" non è più una linea ma un gruppo di voci collegate. Ordinate per data restano leggibili come prima.
- Una versione precedente di IAGO che apra l'archivio vede solo il primo legame di ogni voce, sempre tramite `supersedes_id`, che IAGO continua ad aggiornare con il legame più recente.
