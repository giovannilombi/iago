# Importazione

Tutto quello che non è una call entra da `IAGOIngest`, che dipende solo da `IAGOCore` e lavora con framework di sistema e codice proprio, sul Mac (ADR-0019, ADR-0033).

## Come si smista un file
| Ingresso | Cosa diventa | Come |
|---|---|---|
| Audio, video | elemento da trascrivere (del video si tiene solo l'audio) | AVFoundation, poi la coda di trascrizione |
| Trascrizioni di Teams (`.vtt`, `.docx`) | trascrizione con i **nomi veri** degli speaker | parser del formato recente e di quello vecchio |
| PDF | documento | PDFKit; OCR per le pagine senza testo (`## Pagina N`) |
| Immagini, screenshot | documento | OCR con Vision (`it-IT`, `en-US`, correzione linguistica) |
| DOCX, RTF, ODT | documento | `NSAttributedString` → Markdown con titoli, elenchi e grassetti |
| HTML | documento | convertitore HTML → Markdown proprio, senza WebKit |
| JSON | documento | blocco di codice in Markdown, **un valore per riga e indentato**, chiavi nell'ordine originale (`ContentExtractor.jsonMarkdown`); vale anche per il JSON incollato in *Importa › Da testo* |
| Testo, Markdown, CSV, XML, YAML, log, codice | documento | lettura diretta (ogni tipo di file che macOS riconosce come testo) |
| Email `.eml`, `.emlx`, `.msg` | email con mittente, conversazione e allegati | parser MIME proprio (ADR-0040) |

Un file che IAGO non sa leggere viene rifiutato con un messaggio ("Tipo di file non supportato"), mai in silenzio.

Si conservano **l'originale cifrato** e il **Markdown derivato**; il testo si può correggere a mano e resta la versione automatica di prima.

## Email
- **Nessun accesso alle caselle** (ADR-0020): un'email entra solo per azione dell'utente (trascinamento, file, testo incollato, servizio "Aggiungi a IAGO") o da una **cartella sorvegliata**.
- **Parser MIME proprio:** intestazioni con continuazioni, RFC 2047 e 2231, multipart annidati, base64, quoted-printable, charset IANA, `message/rfc822`, date RFC 5322. Nessuna libreria da verificare.
- **HTML → Markdown senza motore web:** script, stili e immagini scartati, quindi nessun pixel spia caricato.
- **Persone e collegamenti:** indirizzi, conversazioni (`thread_id`), ruoli per dominio (es. "@azienda.example → interno"), proposte di progetto per mittente.
- **Regole di importazione:** riconoscimento di inviti, risposte automatiche e newsletter; regole dell'utente per escludere o assegnare, applicate in ordine.

## Cartelle sorvegliate (ADR-0050)
- Una o più cartelle con le sottocartelle, file `.eml` ed `.emlx`; tipicamente la posta di Outlook salvata da un flusso di **Power Automate** dell'utente in una cartella di OneDrive.
- IAGO le guarda quando cambiano e comunque ogni minuto, perché OneDrive non sempre segnala i file nuovi; importa solo i file nuovi (delta).
- Nessuna rete: IAGO legge file locali.

## Altri ingressi
- **Servizio di macOS "Aggiungi a IAGO"** per il testo selezionato in qualsiasi app.
- **Note** con allegati: il testo estratto entra nella nota; per ogni file IAGO chiede se conservare anche l'originale.
- **Note vocali** trascritte con lo stesso motore delle call (ADR-0021).
