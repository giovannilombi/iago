# ADR-0017 — Contesti per LLM e Claude etichettati per tipo e data

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: v1.4 sez. 10.3, 12; addendum H.17

## Contesto
Chat locale ed MCP forniscono all'LLM contenuti eterogenei (trascrizioni, email, documenti OCR, note) prodotti in momenti diversi e talvolta in conflitto tra loro.

## Decisione
Ogni contenuto passato a un LLM è etichettato con tipo e data (es. "Nota dell'utente del …", email con direzione e data, documenti con avviso di possibili errori OCR). L'istruzione di sistema stabilisce che prevale l'informazione più recente e che i conflitti vanno segnalati; per "cosa vale oggi" si usano le decisioni con stato `active`.

## Conseguenze
- Risposte più affidabili su progetti che evolvono.
- Le descrizioni degli strumenti MCP spiegano tipi di elemento, note, stati delle decisioni ed errori OCR.
