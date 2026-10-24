# ADR-0058 — Il principio sui dati: niente esce senza la scelta dell'utente

- Stato: accettato
- Data: 2026-10-21
- Riferimenti spec: sez. 0 (principi), 4.2 (rete); CLAUDE.md › Rete e privacy; ADR-0005, ADR-0043, ADR-0044, ADR-0048, ADR-0056, ADR-0057; indicazioni dell'utente 2026-10-21

## Contesto
- La spec è nata "privacy first, tutto locale", e i testi dell'app ripetevano "niente lascia questo Mac".
- Nel frattempo IAGO è diventato:
  - collegabile a **Claude** (ADR-0043, 0044);
  - aggiornabile da **GitHub** (ADR-0056);
  - pensato per la **condivisione** in spazi di gruppo (ADR-0057).
- L'utente chiarisce il concetto: IAGO è la **memoria di lavoro interrogabile**, e i dati vanno dove l'utente decide.

## Decisione
- **Il principio:** niente lascia il Mac a meno che l'utente non lo voglia.
- **Tre livelli**, ciascuno scelto in modo esplicito:
  1. **sul Mac, di base:** archivio cifrato, trascrizione e motore locale (MLX) dentro l'app;
  2. **con Claude:** solo i progetti che l'utente abilita, scritture con anteprima e conferma, tutto nel registro accessi;
  3. **in uno spazio condiviso** (fase 4): una cartella cloud controllata dall'utente o dall'azienda (OneDrive, SharePoint, Google Drive, Dropbox). IAGO non ha server.
- **Restano invariati:**
  - nessuna telemetria, statistica o crash reporter remoto;
  - le connessioni che IAGO fa da solo sono solo quelle elencate in CLAUDE.md, controllate in CI da `scripts/check-network-apis.sh`.
- **Comunicazione:** README, guida, tour e impostazioni mettono al centro la memoria interrogabile. La registrazione è una delle fonti, insieme a email, documenti, trascrizioni e note. La privacy si presenta come una scelta, non come un limite.

## Conseguenze
- I testi "nulla lascia il tuo Mac" senza eccezioni sono stati sostituiti in guida, tour, impostazioni e README.
- Ogni nuova strada per far uscire dati (un altro servizio, un altro spazio) richiede un ADR e una scelta esplicita dell'utente nell'interfaccia.
