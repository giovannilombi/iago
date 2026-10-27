# ADR-0072 — Segna momento con screenshot e scorciatoie in tutte le app

- Stato: accettato
- Data: 2026-10-27
- Riferimenti: ADR-0024 (segnalibri), ADR-0019 (OCR con Vision), ADR-0058 (dati), ADR-0060 (niente dati reali), ADR-0067 (MiniCPM), ADR-0071 (Claude); indicazioni dell'utente del 2026-10-27

## Contesto
- Durante le call si condividono slide, tabelle e grafici che la trascrizione non contiene.
- IAGO non catturava lo schermo. Un modello visivo locale (MiniCPM-V) occuperebbe altra memoria su Mac già al limite, e il supporto in MLX Swift va verificato.
- Catture automatiche continue sarebbero pesanti per la privacy: nelle schermate ci sono volti e contenuti di altre persone.
- "Segna momento" e lo stop si usavano solo dal menu dell'icona.

## Decisione
- **«Segna momento con screenshot»**, dal menu dell'icona o con una scorciatoia, **solo su richiesta** dell'utente e durante una registrazione (anche in pausa):
  - cattura con ScreenCaptureKit lo schermo sotto il puntatore (o tutti, a scelta), senza le finestre di IAGO;
  - il testo si legge con l'**OCR di Apple** sul Mac (nessun modello da scaricare, nessuna memoria della GPU);
  - immagine e testo vanno nella cartella della sessione e poi, con la registrazione, nell'archivio cifrato come asset `screenshot` dell'elemento, con il secondo della call e il testo (migrazione `v19-screenshots`).
- **Dove compare:**
  - nella **trascrizione**, una riga «Schermata» al suo minuto con il testo letto;
  - nella scheda, la sezione **Schermate** con le miniature; l'immagine si apre con il testo e si ascolta la call da lì; si può eliminare;
  - nella **ricerca**, come riga della trascrizione a quel minuto;
  - nelle **sintesi e proposte**: il testo entra nelle righe che legge il motore, al suo minuto («Schermata: …»), così un punto può citare una slide.
- **Claude:** legge sempre il testo delle schermate (in `get_item`); le **immagini** con `get_screenshots` solo se l'utente attiva «Condividi con Claude anche le immagini delle schermate» (spento di default), ridotte a 1.568 pixel sul lato lungo. Claude legge slide e grafici meglio dell'OCR.
- **Permesso** «Registrazione schermo» in Impostazioni › Permessi (facoltativo). macOS chiede periodicamente di confermarlo: lo dice la guida.
- **Scorciatoie in tutte le app** (`RegisterEventHotKey`, senza permessi): Segna momento ⌃⌥M, con screenshot ⌃⌥S, Avvia/Stop ⌃⌥R. Si cambiano, si ripristinano o si spengono in Impostazioni › Generale; una combinazione già usata da un'altra app viene segnalata.
- **Niente modello visivo locale per ora:** si valuterà solo se l'OCR non basta, insieme ad ADR-0067.

## Conseguenze
- Le schermate occupano spazio (qualche MB l'una) e sono cifrate come le registrazioni.
- Nessun dato reale nel repository: i test usano immagini e testi inventati.
- Una schermata contiene tutto ciò che c'era sullo schermo, notifiche comprese: per questo è sempre un gesto dell'utente e le immagini non vanno a Claude senza una scelta esplicita.
