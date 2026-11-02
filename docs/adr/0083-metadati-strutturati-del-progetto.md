# ADR-0083 — Metadati strutturati del progetto

- Stato: accettato (principio per la fase 4; nessun codice ancora)
- Data: 2026-11-02
- Riferimenti: ADR-0058 (niente lascia il Mac se l'utente non vuole), ADR-0073 (impronte delle voci), ADR-0082 (sync per tutti i client); review board interna del 2026-11-02

## Contesto
- IAGO vuole essere il cervello condiviso del team: trovare le informazioni senza perdere tempo a cercarle. **Non** sostituisce Salesforce, l'ERP o il tracciamento delle ore, e non va in quella direzione.
- I dati per descrivere il lavoro su un progetto esistono già, sparsi negli elementi: tipo, data, durata, progetto, cliente, categoria, tag, presenti, origine.
- Oggi non c'è un formato che li raccolga per progetto, e con la condivisione serve che chi eredita un progetto (per esempio un manager) li trovi completi e leggibili.

## Decisione
- **Ogni elemento ha un insieme fisso di metadati, senza contenuto:**
  - tipo (call, email, documento), titolo, data, durata;
  - progetto, stream, cliente, categoria, tag;
  - presenti e speaker con nome (solo i nomi);
  - origine (registrazione di IAGO, trascrizione di Teams, email, documento importato) e stato;
  - quanti punti chiave ne sono nati, per tipo.
- **Il progetto porta con sé il registro dei suoi metadati**, allegato al progetto: un elenco leggibile degli elementi con questi campi, che viaggia con il progetto quando è condiviso, nel formato neutro di ADR-0082.
- **Senza contenuto:** niente trascrizioni, testi, audio o note nel registro, e mai impronte delle voci (ADR-0073). Il contenuto resta nell'elemento e segue le sue regole di condivisione.
- I nomi dei campi e il loro formato si fissano nella documentazione tecnica insieme al formato della sync, prima del codice.

## Conseguenze
- Chi riceve un progetto condiviso vede subito cosa è successo e quando, anche senza aprire i contenuti.
- Un conteggio futuro (per esempio le ore di call per progetto) si potrà fare sul registro senza toccare i contenuti. Non è un obiettivo di questa decisione.
- I presenti sono dati personali: entrano nel registro solo se il progetto è condiviso, con le stesse regole del resto del progetto.
