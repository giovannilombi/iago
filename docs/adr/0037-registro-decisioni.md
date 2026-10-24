# ADR-0037 — Registro decisioni e persone

- Stato: accettato
- Data: 2026-10-13
- Riferimenti spec: FR-150…157, FR-174, sez. 8.4.2

## Contesto
La fase 2 introduce le decisioni come oggetti di primo livello, indipendenti dalla fonte (call, documento, nota), con stato e relazione "supera". La spec prevede le persone coinvolte come entità (`decision_entity`), ma la tabella `entity` arriva con l'estrazione della fase 3.

## Decisione
- Migrazione `v6-decisions`: tabelle `decision`, `decision_entity`, `decision_tag` come da spec 8.4.2, più la tabella `entity` della spec (con colonna `normalized` per evitare doppioni), creata ora e usata solo per le **persone digitate dall'utente** sulle decisioni. La fase 3 vi aggiungerà le entità estratte.
- **Titolo e descrizione**: `text` è il titolo (obbligatorio, mostrato in timeline, elenchi, catene, export); `notes` è la descrizione lunga facoltativa, aperta a richiesta ("Dettagli"). Entrambi indicizzati. Un passaggio lungo preso da trascrizione o nota va nella descrizione e la prima frase diventa il titolo.
- Fuori da un progetto ogni decisione mostra in evidenza il suo progetto (o "Da classificare").
- `kind` generico (`decision` | `action` | `open_question`); la UI espone solo `decision` (FR-157).
- **"Supera"**: creare o modificare una decisione che ne supera un'altra porta quest'ultima a `superseded`; togliere il collegamento o eliminare la decisione più recente riporta la precedente ad `active` se nessun'altra la supera. I cicli sono rifiutati.
- **Fonte eliminata (FR-156)**: la decisione conserva testo, data e persone; lo stato della fonte (disponibile, nel cestino, eliminata) è calcolato e mostrato. Nell'indice di ricerca le decisioni non hanno `item_id`, così restano cercabili.
- Le decisioni seguono il progetto del loro elemento quando questo viene spostato (se non erano state spostate a mano). Eliminare un progetto elimina anche le sue decisioni.
- Creazione: da segnalibro (il segnalibro diventa `converted`), da frase della trascrizione (tasto destro; se prima si copia una parte della frase, si usa quella), da documento (testo copiato), da nota ("Promuovi a decisione"), manuale. La proposta automatica arriva con la fase 3.
- Data di default: il momento della call (inizio + timestamp) o la data della nota.

## Conseguenze
- Le note di progetto (blocco 3) potranno essere fonte di decisioni senza modifiche allo schema.
- L'export di progetto (blocco 5) userà `decisionChain` per la sezione "Registro decisioni".

## Aggiornamento 2026-10-13: confronto e nome della catena
- **Altre decisioni:** nel dettaglio di una decisione senza evoluzione compaiono le altre decisioni attive dello stesso stream, o del progetto se la decisione non ha stream. Da lì si collegano con "Questa la supera" (l'altra è più vecchia) oppure "È superata da questa" (l'altra è più recente).
- **Nome della catena:** facoltativo. È salvato in `decision.chain_name` sulla prima decisione della catena (migrazione `v10-decision-chain-name`), si legge da qualsiasi decisione della catena e compare nell'export per LLM come "evoluzione: «nome»".
