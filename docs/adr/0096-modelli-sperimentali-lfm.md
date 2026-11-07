# ADR-0096 — Modelli LFM2.5 8B-A1B e 24B-A2B: provati e non integrati

- Stato: rifiutato
- Data: 2026-11-06
- Riferimenti: ADR-0048 (catalogo del motore locale), ADR-0054 (sintesi, almeno 9B), ADR-0067 (MiniCPM, rifiutato); [prova del 2026-11-06](../benchmarks/2026-11-06-modelli-lfm.md); richiesta dell'utente del 2026-11-06

## Contesto
- Sui Mac con 16 GB l'unico modello che fa le sintesi è Qwen 3.5 9B: circa 6 GB di memoria, e il Mac rallenta mentre lavora. La priorità è servire meglio chi ha poca memoria.
- Liquid AI ha pubblicato due modelli «a esperti», che per ogni parola usano solo una parte dei parametri:

  | Modello | Parametri | Attivi per parola | Peso a 4 bit |
  |---|---|---|---|
  | LFM2.5 8B-A1B | 8,3 miliardi | 1,5 miliardi | 4,8 GB |
  | LFM2.5 24B-A2B | 24 miliardi | circa 2,4 miliardi | 13,6 GB |

  Secondo le prove del produttore seguono bene le istruzioni e inventano meno dei modelli della stessa taglia. Esistono in versione MLX ufficiale, e l'architettura `lfm2_moe` è già nella versione di MLX Swift che usiamo.
- **Contro:**
  - ragionano sempre prima di rispondere, e non c'è un modo documentato per spegnere il ragionamento;
  - non ci sono prove pubblicate in italiano;
  - la licenza *LFM Open License v1.0* permette l'uso commerciale gratuito solo sotto i 10 milioni di dollari di fatturato annuo.
- **La prova:** per misurarli sono stati aggiunti al catalogo come modelli sperimentali. IAGO toglieva il ragionamento dalle risposte o provava a saltarlo con un blocco `<think>` vuoto. Sono stati provati sulle stesse tre call della prova del 21 ottobre.

## La prova
I dettagli sono in [docs/benchmarks/2026-11-06-modelli-lfm.md](../benchmarks/2026-11-06-modelli-lfm.md).

**LFM2.5 8B-A1B:**
- **sintesi con il ragionamento:** 183-227 s per call e 0-3 punti, contro i 73-123 s e 10-35 punti di Qwen 3.5 9B. Il ragionamento consuma i token e spesso non resta nessuna risposta;
- **sintesi con il ragionamento saltato:** è veloce (38 s sulla prima call), ma copia il parlato invece di riassumerlo: 1-11 punti tenuti e 186 scartati;
- **proposte:** le fa in 32 s, il tempo migliore del catalogo, ma 22 su 27 citavano frasi che nella call non c'erano;
- **Riordina testo:** in 5 s, ma in un passaggio ha perso quattro fatti;
- **memoria di picco:** 5-6 GB, poco meno di Qwen 3.5 9B.

**LFM2.5 24B-A2B:** ragiona in chiaro fino al limite di token anche quando il ragionamento viene saltato, e anche senza penalità di ripetizione. Ha impiegato 347 s per una call, senza nessun punto di sintesi; Gemma 4 12B fa la stessa call in circa 275 s.

## Decisione
- I due modelli **non entrano nel catalogo**, nemmeno come sperimentali: per le funzioni di IAGO rendono meno dei modelli che ci sono già.
- Il codice scritto per la prova non resta nell'app:
  - il gruppo *Modelli sperimentali*;
  - la gestione del ragionamento;
  - il segno «· sperimentale».
- **Per i Mac con 16 GB** restano Qwen 3.5 9B per le sintesi e Claude come alternativa (ADR-0095).

## Conseguenze
- Il catalogo e l'app restano come prima.
- La prova resta documentata, per non ripeterla allo stesso modo.
- Se ne vale la pena, si riprova con una versione nuova dei modelli o di MLX Swift, oppure quando ci sarà un modo documentato per spegnere il ragionamento:
  - la prova si rifà sulle stesse call, con `-IAGOSummaryBench` e `-IAGOEngineBench`;
  - per gestire il ragionamento si riparte dalla descrizione nella prova.
