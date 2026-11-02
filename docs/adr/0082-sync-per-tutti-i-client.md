# ADR-0082 — Sincronizzazione utilizzabile da tutti i client

- Stato: accettato (principio per la fase 4; nessun codice ancora)
- Data: 2026-11-02
- Riferimenti: ADR-0012 e ADR-0057 (sync), ADR-0058 (niente lascia il Mac se l'utente non vuole), ADR-0073 (impronte delle voci); review board interna del 2026-11-02

## Contesto
- Oggi IAGO esiste solo per macOS: SwiftUI e AppKit, process tap per l'audio, MLX per il motore locale, Portachiavi per le chiavi. Nessuna di queste parti si porta su un'altra piattaforma.
- La condivisione dei progetti (fase 4) è il primo lavoro dopo la pubblicazione.
- Più avanti potrà servire una versione per Windows, per chi riceve un computer non Apple. Sarà una riscrittura, non un porting.
- Se il formato della sync dipende da tecnologie Apple, un client futuro non potrà leggere né scrivere gli spazi condivisi dei Mac.

## Decisione
- **Lo spazio condiviso e il protocollo di sync sono neutri rispetto alla piattaforma.** Qualunque client (macOS oggi; Windows, riga di comando o altro domani) deve poterli leggere e scrivere senza codice Apple:
  - file di testo documentati (JSON) con la **versione del formato**, ID stabili, orologi logici (HLC) e asset indirizzati per contenuto (SHA-256);
  - niente formati propri di Apple (plist binari, `NSKeyedArchiver`, Core Data) e niente dipendenza dal Portachiavi per leggere lo spazio;
  - cifratura e scambio delle chiavi di progetto solo con primitive standard, disponibili su ogni piattaforma.
- **Il formato si scrive prima del codice**, nella documentazione tecnica, ed è coperto da fixture di test: un lettore indipendente dal codice Swift (per esempio uno script) deve saper leggere e scrivere uno spazio di prova.
- **Le regole di risoluzione stanno nel formato, non nel client**, così ogni client decide allo stesso modo. Indicazione dell'utente: ogni progetto condiviso ha sempre un **referente** e, quando due persone confermano una stessa proposta in modo diverso, vale la scelta del referente.
- Restano solo sul dispositivo, per ogni client: impronte delle voci (ADR-0073), preferenze e chiavi personali. Ciò che si condivide resta una scelta dell'utente, tracciata nel registro accessi (ADR-0058).

## Conseguenze
- Un client per un'altra piattaforma può nascere senza cambiare i Mac né gli spazi esistenti.
- La sync non può usare scorciatoie disponibili solo su Apple: va scritta e provata sul formato.
- Il progetto della sync (ADR-0057, `docs/design/sync-cartella-condivisa.md`) va verificato contro questo principio prima di essere accettato.
