# Architecture Decision Records

Ogni decisione architetturale rilevante ha un ADR numerato. Un ADR accettato non si modifica: per cambiarlo si scrive un nuovo ADR che lo sostituisce (`Stato: sostituito da ADR-XXXX`).

## Formato

```markdown
# ADR-NNNN — Titolo

- Stato: proposto | accettato | rifiutato | sostituito da ADR-XXXX
- Data: AAAA-MM-GG
- Riferimenti spec: sez. …

## Contesto
## Decisione
## Conseguenze
```

## Indice

0001–0012: decisioni della spec v1.0 (sez. 17). 0013–0021: decisioni dell'addendum v1.4 (sez. H, stesso ordine). Dalla 0022: decisioni aperte risolte durante lo sviluppo.

| # | Titolo | Stato |
|---|---|---|
| 0001 | App nativa Swift/SwiftUI, nessun fork | accettato |
| 0002 | Due tracce separate, mix solo per l'ascolto | accettato |
| 0003 | Traccia sistema via Core Audio process tap globale | accettato |
| 0004 | Traccia mic = microfono in uso dall'app di call | accettato |
| 0005 | Trascrizione esclusivamente locale, motori intercambiabili | accettato |
| 0006 | VAD e diarizzazione con FluidAudio | accettato |
| 0007 | SQLite (GRDB), file cifrati per riga, crypto-shredding | accettato |
| 0008 | UUIDv7, tombstone, versioni e change log da subito | accettato |
| 0009 | Tag ed entità automatici solo come suggerimenti | accettato |
| 0010 | Accesso Claude per progetto, MCP stdio, registro accessi | accettato |
| 0011 | Notion escluso | accettato |
| 0012 | Sync futura E2E su Cloudflare, nessun servizio esterno prima | accettato |
| 0013 | Decisioni come oggetti di primo livello | accettato |
| 0014 | Modello `decision` generico (`kind`) | accettato |
| 0015 | Grafo come proiezione calcolata, vista nativa centrata | accettato |
| 0016 | Note multiple e datate | accettato |
| 0017 | Contesti per LLM e Claude etichettati per tipo e data | accettato |
| 0018 | L'elemento è un evento tipizzato nella cronologia del progetto | accettato |
| 0019 | Estrazione di testo e OCR esclusivamente locali | accettato |
| 0020 | Nessun accesso automatico alle caselle email | accettato |
| 0021 | Le note vocali sono note normali; l'audio non si conserva | accettato |
| 0022 | macOS minimo 15 (decisione aperta A) | accettato |
| 0023 | Motore ASR di default: whisper.cpp large-v3-turbo (decisione aperta B) | accettato |
| 0024 | "Segna momento" punta a 5 secondi prima del clic | accettato |
| 0025 | Scelta del microfono: più ingressi per app e attesa prima del ripiego | accettato |
| 0026 | Clic sinistro apre il menu, clic destro avvia e mette in pausa | accettato |
| 0027 | File cifrati a blocchi AES-GCM | accettato |
| 0028 | Master key nel Portachiavi e chiavi per elemento | accettato |
| 0029 | Registrazioni della fase 0 importate nell'archivio cifrato | accettato |
| 0030 | Cestino con eliminazione automatica dopo 30 giorni (decisione aperta D) | accettato |
| 0031 | Opzione "Più persone nella stanza" | accettato (IAGO decide da solo e presenti: 1.2.8-beta) |
| 0032 | "Scarta" durante la registrazione e "Scartate temporanee" | accettato |
| 0033 | Import generico, trascrizioni Teams e allegati nelle note | accettato (trascrizione Teams affiancata: 0078) |
| 0034 | Licenza di IAGO: Creative Commons BY-NC-SA 4.0 | accettato |
| 0035 | "Non definito" e gestione dei progetti | accettato |
| 0036 | Indice di ricerca FTS5 e controllo delle API di rete | accettato |
| 0037 | Registro decisioni e persone | accettato |
| 0038 | Gerarchia Cliente › Progetto › Stream | accettato |
| 0039 | Note di progetto, allegati di progetto e note vocali | accettato |
| 0040 | Email: parser MIME locale, conversazioni, collegamenti e persone | accettato |
| 0041 | Backup cifrato, nuovo Mac, export e specchio Obsidian | accettato |
| 0042 | Titoli proposti dal modello Apple sul Mac | accettato |
| 0043 | Server MCP per Claude | accettato |
| 0044 | Scrittura tramite Claude (MCP) | accettato |
| 0045 | Vista a grafo | accettato |
| 0046 | Punti chiave: decisioni, attività e tappe | accettato |
| 0047 | Claude scrive con contesto e anteprima | accettato |
| 0048 | Motore locale (LLM sul Mac) | accettato |
| 0049 | Ricerca per significato, proposte automatiche e chat | accettato |
| 0050 | Cartelle sorvegliate per le email | accettato |
| 0051 | Riconoscere le riunioni Teams, proporre la registrazione e seguire il mute | accettato |
| 0052 | Superamenti multipli e tra tipi diversi | accettato |
| 0053 | Cancellazione dell'eco di macOS sul microfono | ritirato |
| 0054 | Sintesi in base alla categoria | accettato |
| 0055 | Sezione "Attività" | accettato |
| 0056 | Aggiornamenti dell'app | accettato (2 giorni di margine per gli obbligatori: 1.2.8-beta) |
| 0057 | Sincronizzazione tramite una cartella cloud condivisa | proposto |
| 0058 | Il principio sui dati: niente esce senza la scelta dell'utente | accettato |
| 0059 | Distribuzione senza notarizzazione | accettato (DMG dal 2026-10-27) |
| 0060 | Pubblicazione del repository | accettato (repository pulito fatto con ADR-0065; pubblicazione da fare) |
| 0061 | Guida integrata, tour di benvenuto e archivio dimostrativo | accettato |
| 0062 | Glossario della trascrizione | accettato |
| 0063 | Barra laterale e accesso trasversale a categorie e tag | accettato |
| 0064 | Pulizia dell'eco dopo la registrazione | rifiutato |
| 0065 | Repository pulito, 1.0.0-beta e niente dati reali nei commit | accettato |
| 0066 | Esempio iniziale in un archivio nuovo | accettato (progetti di esempio con contenuti: 1.2.10-beta) |
| 0067 | MiniCPM: al posto di Qwen 3.5 4B o in aggiunta | rifiutato |
| 0068 | Sito di documentazione con VitePress su GitHub Pages | accettato (online quando il repository è pubblico) |
| 0069 | Coda unica del motore e memoria | accettato |
| 0070 | Chi ha prodotto ogni risultato | accettato |
| 0071 | Sintesi e proposte fatte da Claude | accettato |
| 0072 | Segna momento con screenshot e scorciatoie in tutte le app | accettato |
| 0073 | Riconoscere le stesse voci in call diverse | accettato (voci della stanza: 1.2.8-beta) |
| 0074 | Lavoro aperto e due modalità: Traccia e Gestisci | accettato (1.1.0-beta; modalità ridefinite da 0076) |
| 0075 | Viste di progetto: come guardare e cosa mostrare | accettato (1.1.0-beta; in parte sostituito da 0076) |
| 0076 | Modalità Traccia semplice, Inbox ed Elementi | accettato (1.2.0-beta) |
| 0077 | Italiano e inglese, sempre allineati | accettato (1.2.2-beta) |
| 0078 | Trascrizioni di IAGO e di Teams affiancate, Claude consigliato sui Mac lenti | accettato (1.2.5-beta; ricerca in tutte e due e ★ sulla principale: 1.2.6-beta) |
| 0079 | Assistenti oltre Claude: Claude, Claude Code, Gemini, Gemini CLI, ChatGPT, Codex CLI | proposto |
| 0080 | Condividere un elemento | accettato (1.2.7-beta) |
| 0081 | Introduzione all'uso | accettato (1.2.9-beta) |
| 0082 | Sincronizzazione utilizzabile da tutti i client | accettato (principio, fase 4) |
| 0083 | Metadati strutturati del progetto | accettato (principio, fase 4) |
| 0084 | Dettaglio dell'elemento: tile, barra fissa e momenti | accettato (1.2.11-beta) |
| 0085 | Riepilogo a box, Traccia divisa in due, Attività a tutta finestra | accettato (1.2.12-beta) |
| 0086 | Stile: colore come segnale, chiaro e scuro | accettato (1.2.13-beta) |
| 0087 | Inbox a due metà, proposte a destra, colonne per sezione | accettato |
| 0088 | Ordine delle sezioni dell'elemento e barra laterale | accettato |
| 0089 | Co-autori dei commit fino alla condivisione | accettato |
| 0090 | Categorie e tag a tre colonne | accettato |
| 0091 | Contesto di «Chiedi a IAGO» con più progetti | accettato |
| 0092 | Ricerca nella spalla destra e «Chiedi a IAGO» a tutta finestra | accettato |
| 0093 | Pallino giallo e pannelli quando il microfono non registra | accettato |
| 0094 | Riconoscimento delle voci acceso, nomi degli speaker più semplici, il tuo nome | accettato |
| 0095 | Claude come alternativa su ogni Mac, con i passi, e riavvio di Claude Desktop | accettato |
