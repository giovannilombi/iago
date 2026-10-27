# Intelligenza

`IAGOIntelligence` trasforma il testo in risposte. Usa il motore locale tramite il protocollo `LanguageModel` di `IAGOCore`: il pacchetto non dipende da MLX, e i test usano un motore finto.

## Ricerca
- **Testo pieno:** SQLite FTS5 con accenti e maiuscole ignorati, aggiornato al salvataggio (ADR-0036).
- **Per significato:** il testo viene diviso in pezzi (*chunk*) con l'elemento e il minuto d'origine, trasformati in vettori da **Qwen3 Embedding 0.6B** (MLX 4 bit, *last-token pooling*); la similarità è il coseno su una matrice in memoria (ADR-0049).
- **Ricerca ibrida:** i due elenchi vengono uniti con *reciprocal rank fusion*. Senza il modello di embedding resta la ricerca per parole.
- **Ambito:** tutta la memoria, un cliente, un progetto o uno stream.

## Punti chiave (ADR-0046, ADR-0052)
- Tipi: decisione, attività, tappa e altri (`kind`), con fonte (elemento e minuto, oppure nota), persone, data.
- **Superamenti:** una voce può superarne una o più, anche di tipo diverso; la catena resta consultabile ("Supera", "Superata da").
- Registro globale dei punti chiave e timeline di progetto (ADR-0037).

## Proposte (ADR-0009, ADR-0049)
Dopo ogni nuovo contenuto il motore propone decisioni, attività, nomi degli speaker, tag, progetto e collegamenti. Ogni proposta porta **la frase da cui viene**; IAGO la cerca nel testo e scarta quelle che non trova. Niente viene applicato senza conferma.

## Sintesi per categoria (ADR-0054)
- La **categoria** dell'elemento sceglie il **modello di sintesi**: 18 modelli nel formato JSON di Meetily (sezioni con istruzione, formato e formato delle voci), presi da Meetily e Hyprnote (MIT) e modificabili.
- Serve un motore da **almeno 9B** di parametri (`EngineCatalog.minimumBillions["summary"] = 9`).
- **Come si evita che il modello inventi:**
  - la call viene letta a **blocchi di 10 minuti** (o 10.000 caratteri per i testi senza minuti). Una riga più lunga di 2.500 caratteri, come un JSON compatto o un testo senza a capo, viene prima tagliata alla fine di una frase o a uno spazio (`TextPieces`): nessuna richiesta al motore può superare il limite e riempire la memoria. Lo stesso limite vale per *Riordina testo*;
  - ogni punto deve riportare una **citazione**; `KeyPointExtractor.locate` la cerca nella trascrizione con i numeri identici e collega il punto al suo minuto, altrimenti il punto viene scartato;
  - le frasi parlate copiate invece che riassunte, i fatti personali e gli aneddoti restano fuori;
  - le sezioni vuote dicono "Non emerso"; "In breve" si scrive solo dai punti verificati;
  - JSON compatto con un limite di 2500 token; se la risposta è troncata o malformata, la si legge sezione per sezione e poi per schemi.
- I minuti nella sintesi sono link `iago://seek/N` che fanno ripartire l'audio.

## Chiedi a IAGO (ADR-0049)
1. La domanda cerca nel **contesto** scelto (stream, progetto, cliente o tutta la memoria) con la ricerca ibrida, fino a 40 pezzi.
2. I pezzi vengono raggruppati per elemento e numerati come **fonti**; il modello riceve solo quelle, con un contesto etichettato (ADR-0017).
3. La risposta deve citare le fonti `[n]`; un clic su una fonte apre l'elemento al minuto.
4. Le conversazioni restano 48 ore, a meno di conservarle; riaprendone una, IAGO segnala il materiale nuovo arrivato dopo l'ultima risposta.
5. "Allarga contesto" passa al livello superiore e ripete l'ultima domanda in una conversazione nuova.

## Titoli brevi (ADR-0042)
Quando un testo lungo diventa un punto chiave, Apple Foundation Models (macOS 26, se Apple Intelligence è attivo) propone un titolo di al massimo 8 parole. Sul Mac, senza rete.

## Grafo (ADR-0015, ADR-0045)
Una proiezione in sola lettura di elementi, persone, decisioni e collegamenti di un progetto, costruita dai dati esistenti.
