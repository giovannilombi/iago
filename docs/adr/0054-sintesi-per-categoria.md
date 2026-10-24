# ADR-0054 — Sintesi in base alla categoria

- Stato: accettato (flusso e regole approvati dall'utente il 2026-10-21; categorie in più da decidere)
- Data: 2026-10-21
- Riferimenti spec: categorie (sez. 8); ADR-0046 (punti chiave), ADR-0048 (motore locale); richieste utente 2026-10-13, 2026-10-16, 2026-10-21

## Contesto
Le categorie delle call (1to1, Kickoff, SAL, Workshop, Review/Demo, Commerciale, Interna, Altro) esistono perché l'utente vuole sintesi diverse per tipo di riunione, come fa Plaud. Ora il motore locale c'è (ADR-0048).

L'utente non vuole reinventare la ruota. Due progetti open source fanno già sintesi con modelli per tipo di riunione e un modello locale:
- **Meetily** (github.com/Zackriya-Solutions/meeting-minutes, MIT, © 2024 Zackriya Solutions): 6 modelli in JSON, ciascuno con sezioni che hanno titolo, istruzione per il modello, formato (paragrafo, elenco, testo breve) e, per gli elenchi, colonne di tabella;
- **Hyprnote**, oggi Anarlog (github.com/fastrepl/hyprnote, MIT, © 2023 Fastrepl): 17 modelli (1:1, kickoff di progetto e cliente, brainstorming, discovery commerciale, design review, retrospettiva, postmortem…), ciascuno con sezioni che hanno titolo e descrizione.

Plaud non è open source: i suoi modelli non si possono riprendere.

## Decisione
### Modelli di sintesi
- **Formato:** lo stesso JSON di Meetily (`name`, `description`, `sections[]` con `title`, `instruction`, `format` e `item_format` facoltativo). Così si potranno importare ed esportare modelli scritti per Meetily.
- **Contenuto:** i modelli di Meetily e Hyprnote, tradotti e adattati alle 8 categorie, con attribuzione in `docs/licenses.md` come chiede la licenza MIT:

| Categoria | Basato su | Sezioni |
|---|---|---|
| **1to1** | Hyprnote "1:1 Meeting" | Aggiornamenti · Successi e difficoltà · Obiettivi e avanzamento · Feedback, nei due sensi · Impegni (Chi · Cosa · Entro) |
| **Kickoff** | Hyprnote "Project Kickoff" e "Client Kickoff" | Panoramica (perimetro, obiettivi, consegne) · Criteri di successo · Persone e ruoli · Tempi e tappe (Tappa · Data) · Rischi e dipendenze · Come ci si aggiorna · Prossimi passi |
| **SAL** | Meetily "Project Sync" | Avanzamento · Tappe e stato (Tappa · Stato · Previsione) · Rischi e contromisure (Rischio · Impatto · Contromisura · Chi) · Decisioni (Decisione · Motivo · Minuto) · Attività (Chi · Cosa · Entro) |
| **Workshop** | Hyprnote "Brainstorming Session" | Obiettivo della sessione · Idee emerse · Idee più promettenti · Criteri per valutarle · Prossimi passi |
| **Review/Demo** | Hyprnote "Technical Design Review" | Cosa è stato presentato · Feedback (Punto · Feedback · Chi) · Modifiche richieste · Approvato e da rivedere · Prossimi passi |
| **Commerciale** | Meetily "Client / Sales Meeting" e Hyprnote "Sales Discovery Call" | Contesto del cliente · Situazione attuale e problemi · Obiettivi e criteri di successo · Budget, tempi e condizioni · Obiezioni e dubbi · Concorrenti citati · Prossimi passi (Chi · Cosa · Entro) |
| **Interna**, **Altro** | Meetily "Standard Meeting Notes" | Sintesi · Decisioni · Attività (Chi · Cosa · Entro · Minuto) · Punti salienti della discussione |

- **In ogni sintesi:**
  - **In breve**, 3 righe in cima;
  - **data e partecipanti presi dai dati di IAGO** (elemento, persone, calendario), non dal modello: a differenza di Meetily, il modello non li deve indovinare.
- **Le categorie restano aperte:** l'utente le crea, rinomina, archivia e riordina come oggi.
- **Raccolta di modelli:** IAGO include tutti i modelli dei due progetti, tradotti e adattati: 6 di Meetily e 17 di Hyprnote, quelli doppi uniti. Ogni categoria usa un modello della raccolta:
  - le 8 categorie attuali partono con quelli della tabella sopra;
  - una categoria nuova sceglie il suo alla creazione, con una proposta in base al nome;
  - "Nessuna sintesi" è una scelta valida.
- **Modelli modificabili** in Impostazioni › Categorie: sezioni, istruzioni e colonne. "Ripristina l'originale" torna al modello della raccolta.

### Regole per l'affidabilità
Sono le stesse dei punti chiave (ADR-0046):
- ogni punto porta il **minuto** da cui viene. IAGO verifica che la frase citata ci sia davvero, con i numeri identici; se non la trova, il punto viene scartato;
- una sezione senza contenuto dice **"Non emerso"**: il modello non riempie per forza;
- **call lunghe:** blocchi da 10 minuti, prima una sintesi per blocco e poi una d'insieme;
- italiano; nessun nome inventato per chi parla;
- decisioni e attività che sono già nel registro dei punti chiave vengono collegate, non riscritte.

### Quando parte
- **A fine trascrizione, da sola, solo se l'elemento ha già una categoria** e il motore è installato.
- **Senza categoria** non parte. Il blocco **Sintesi** c'è comunque, sempre visibile nella scheda, con:
  - il messaggio "Sintesi non ancora disponibile";
  - la scelta della categoria (che è anche la categoria dell'elemento);
  - il pulsante **"Genera sintesi"**.
- **Senza motore** il blocco spiega che serve il motore locale, con il collegamento a Impostazioni › Motore.
- **Cambiando categoria** a sintesi già fatta, il blocco propone "Rigenera con il modello «…»". Non rigenera da solo. Se la sintesi è stata modificata a mano, chiede conferma prima di sostituirla.
- **Mentre la genera**, il blocco mostra l'avanzamento per blocchi, che compare anche in Attività (ADR-0055).

### Dati e prestazioni
- Tabella `summary`, migrazione `v17-summaries`, con backup prima dell'installazione. Contiene:
  - elemento, categoria, versione del modello di sintesi;
  - testo Markdown;
  - motore usato;
  - "modificata a mano";
  - data.
- La sintesi entra nella ricerca, nelle esportazioni, in Obsidian, in Chiedi e in Claude (MCP, sola lettura).
- **Lavoro della coda** `summary` (QoS `.utility`, uno alla volta, dopo la trascrizione). Tempi attesi per una call di 30 minuti, sul Mac dell'utente:

| Modello | Tempo misurato (call di 29 min, 2026-10-21) | Memoria | Esito |
|---|---|---|---|
| Qwen 3.5 4B | 112 s | 3,3 GB | pochi punti tenuti (6), molti scartati: debole |
| Qwen 3.5 9B | 167 s | 6,1 GB | buono: 20 punti, attività ripetevano "chi" (corretto) |
| Gemma 4 12B | 325 s | 12,4 GB | il migliore: decisioni giuste, cifre esatte |

- Solo motore locale, nessuna Apple Intelligence (ADR-0048).

## Conseguenze
- Le categorie servono a qualcosa e la sintesi ha la forma giusta per il tipo di riunione, senza inventare modelli da zero.
- La qualità dipende dalla trascrizione. Prima di attivarla di default si prova su 2-3 call reali di categorie diverse, con una scheda di valutazione.
- Rispetto a Meetily: verifica delle citazioni, data e partecipanti presi dai dati, "Non emerso" al posto delle sezioni riempite a forza.

## Messa a punto dopo la prima prova (2026-10-21)
- Le sezioni di **panoramica** (formato paragrafo: Contesto, Panoramica, Avanzamento…) riassumono tutto il blocco e raramente hanno una frase da citare. Restano senza minuto, purché ogni numero che contengono sia detto nel blocco.
- La citazione può stare in 3 battute consecutive (per i punti chiave restano 2).
- Valori come "non specificato" diventano "—"; nelle tabelle il testo non ripete chi e quando.
- Il modello "Riunione standard" non ha più la sezione "Sintesi", che duplicava "In breve".
- **Categorie su due livelli:** le principali sono sempre visibili; le famiglie (Agile, Direzione, Persone, Operazioni) si accendono in Impostazioni › Categorie e compaiono come sottomenu. "Commerciale" diventa "Client/Sales"; "Customer discovery" si aggiunge tra le principali.
- **Barra laterale:** i clienti sono intestazioni in maiuscoletto, categorie e tag escono dalla barra. Si raggiungono da "Categorie e tag", dalla ricerca (`#tag`, `categoria:`), dalla scheda (clic su categoria o tag) e si possono fissare in "In evidenza".

## Modifica del 2026-10-21 (2): dalla prova su tre call reali
- **Istruzioni al modello:**
  - "testo" è un riassunto in terza persona di al massimo 15 parole, non la frase detta;
  - la citazione è breve;
  - al massimo 4 punti per sezione e per blocco;
  - niente chiacchiere, niente **fatti personali** (salute, famiglia);
  - le **decisioni** sono solo quelle prese nella riunione, non i racconti.
- **Controlli di IAGO:**
  - scarta i punti che coincidono con la citazione o iniziano in minuscolo (parlato copiato);
  - toglie il nome ripetuto ("Mario deve…" quando la colonna Chi dice già Mario).
- **Lettura delle risposte:**
  - JSON compatto e risposte fino a 2.500 token;
  - se il JSON è troncato si tiene l'ultimo punto completo;
  - ogni sezione `{"titolo": …}` si legge per conto suo;
  - se le parentesi sono sbagliate si leggono testi e citazioni per schemi.
- **Motore minimo:** 9B (ADR-0048, modifica del 2026-10-21).
