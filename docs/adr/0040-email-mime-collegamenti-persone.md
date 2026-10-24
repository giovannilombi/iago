# ADR-0040 — Email: parser MIME locale, conversazioni, collegamenti e persone

- Stato: accettato
- Data: 2026-10-13
- Riferimenti spec: FR-180…185, FR-200…203, sez. 8.4.2; richiesta utente (trascinamento da Outlook, persone del cliente)

## Contesto
Le email arrivano come `.eml` (anche trascinate da Outlook o Mail come file "promessi"), come testo incollato o come screenshot. Servono parsing MIME, conversazioni, allegati come documenti collegati e il riconoscimento delle persone per proporre il progetto. Nessun servizio esterno, nessuna rete.

## Decisione
- **Parser MIME proprio** (`IAGOIngest/EmailParser.swift`), invece di una libreria:
  - copre intestazioni con continuazioni, parole codificate RFC 2047, parametri RFC 2231, multipart annidati, base64, quoted-printable, charset tramite IANA, `message/rfc822` inline, date RFC 5322;
  - nessuna dipendenza in più da verificare e mantenere.
- **HTML → Markdown con un convertitore proprio**, non con `NSAttributedString`/WebKit, che potrebbero caricare immagini remote (pixel spia). Script, stili e immagini vengono scartati; restano titoli, paragrafi, elenchi, link, grassetti e citazioni. Se esiste, si usa il corpo `text/plain`.
- **Archivio (migrazione `v9-email`):**
  - `email_meta` come da spec, con indirizzi in JSON e `thread_id`;
  - `item_link` come da spec;
  - una nuova tabella `contact` (persona = `entity`, email, ruolo interno/cliente/fornitore, cliente o progetto; entrambi nulli = colleghi dell'utente).
  - Le persone dei contatti sono le stesse entità suggerite sulle decisioni.
- **Conversazioni:** un'email entra nella conversazione del messaggio a cui risponde (`In-Reply-To`, poi `References`) e viene collegata con `reply_to`. Le risposte già in archivio vengono riagganciate anche se il messaggio originale arriva dopo.
- **Direzione:** è "inviata" se il mittente è tra gli indirizzi dell'utente (Impostazioni › Email e persone), altrimenti "ricevuta". Si può sempre cambiare.
- **Allegati:**
  - diventano documenti collegati con `attachment_of`, nello stesso progetto dell'email;
  - sono preselezionati tutti tranne le immagini sotto 20 KB (firme e loghi);
  - l'originale `.eml` è conservato cifrato.
- **Domini noti** (richiesta utente): una regola per dominio vale in tutta l'app e si estende ai sottodomini. È salvata nell'impostazione `email_domain_rules`.
  - Per esempio `@azienda.it` → interno, oppure `@fornitore.it` → fornitore.
  - Un dominio con ruolo cliente può essere legato a un cliente: lo si aggiunge dalla finestra "Persone…" del cliente, e fa proporre i suoi progetti.
  - Una persona aggiunta per nome vale più del dominio.
  - Accanto a ogni indirizzo delle email compare l'etichetta Interno / Cliente / Fornitore.
- **Progetto suggerito:** si guardano i mittenti e i destinatari che sono contatti di un cliente o di un progetto (i colleghi non contano). Se il cliente ha un solo progetto, viene proposto quello.
- **Trascinamento da Outlook e Mail:** la finestra accetta file, `public.email-message` e dati. Un elemento che non è un file viene letto con `loadFileRepresentation` e copiato nella cartella temporanea. I tipi offerti vengono scritti nel log (senza contenuto), così un trascinamento non riconosciuto si può diagnosticare. I trascinamenti di solo testo vengono ignorati.

## Conseguenze
- Il formato `.msg` di Outlook per Windows non è supportato: da Outlook per Mac il trascinamento produce `.eml`.
- La proposta automatica di collegamenti tramite LLM arriva nella Fase 3, sempre da confermare.
