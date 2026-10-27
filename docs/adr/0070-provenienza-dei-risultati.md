# ADR-0070 — Chi ha prodotto ogni risultato

- Stato: accettato
- Data: 2026-10-27
- Riferimenti: ADR-0048 (motore locale e modelli), ADR-0049 (proposte e Chiedi), ADR-0054 (sintesi), ADR-0071 (sintesi e proposte scritte da Claude); indicazioni dell'utente del 2026-10-27

## Contesto
- La qualità di una sintesi o di una proposta dipende dal modello: un 4B ne trova meno di un 9B (prove del 2026-10-16 e del 2026-10-21).
- IAGO salvava il modello delle sintesi, delle proposte e delle risposte di Chiedi, ma lo mostrava solo per le sintesi e le risposte; sui punti chiave confermati da una proposta si perdeva.
- Con ADR-0071 sintesi e proposte possono arrivare anche da Claude: va detto da dove vengono.

## Decisione
- **Ogni risultato dice chi l'ha prodotto**, con la stessa riga ovunque:
  - sintesi: «Sintetizzata con Qwen 3.5 9B sul Mac» oppure «Sintetizzata da Claude»;
  - proposte: «Proposta da Qwen 3.5 4B sul Mac» oppure «Consigliata da Claude»;
  - punti chiave confermati da una proposta: «Proposto da Qwen 3.5 4B sul Mac, confermato da te» oppure «Consigliato da Claude, confermato da te»;
  - risposte di Chiedi: il nome del modello, come già oggi.
- **Per il motore locale conta il modello**: accanto a un risultato di un modello sotto i 9B compare «modello piccolo», con il suggerimento di usarne uno più grande. **Per Claude basta sapere che è Claude**: il server MCP non sa quale modello di Claude lo chiama, conosce solo l'app (per esempio Claude Desktop), che si salva come informazione.
- **Dati** (migrazione `v18-provenance`):
  - `summary.origin` e `suggestion.origin`: `engine` o `claude` (predefinito `engine`, per tutto ciò che c'era già);
  - `decision.model`: l'id del modello del catalogo, o `claude`, per i punti chiave confermati da una proposta;
  - `model` resta l'id del catalogo; il nome si legge dal catalogo e, se un modello sparisce, si mostra l'id.
- Una nuova esecuzione del motore sostituisce solo le **proprie** proposte in attesa: non cancella quelle di Claude, e viceversa.

## Conseguenze
- L'utente sa sempre quanto fidarsi di un risultato e capisce quando conviene un modello più grande.
- Le note e i punti chiave scritti a mano non hanno modello: non sono prodotti da un motore.
