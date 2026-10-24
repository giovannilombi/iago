# ADR-0035 — "Non definito" e gestione dei progetti

- Stato: accettato (richiesta dell'utente, 2026-10-12)
- Data: 2026-10-12
- Riferimenti spec: FR-21, FR-40, FR-70

## Contesto
"Da classificare" mostra gli elementi senza progetto né categoria. Un elemento con categoria ma senza progetto non compariva in nessun progetto e rischiava di perdersi. L'utente vuole inoltre gestire i progetti (rinomina, archiviazione, eliminazione).

## Decisione
- **"Da classificare"** = tutti gli elementi **senza progetto**, con o senza categoria: un elemento ne esce solo quando riceve un progetto.
- **"Non definito"**: voce fissa, sempre prima tra i Progetti, non eliminabile, non rinominabile, senza pin. Non è una riga del database ma una vista: elementi senza progetto ma con una categoria (che restano anche in "Da classificare"). Nei selettori "Nessun progetto" diventa "Non definito".
- **Impostazioni › Progetti**: rinomina (i dati restano collegati per ID), archivia/ripristina (gli archiviati spariscono da barra laterale e selettori, restano qui con tutto il contenuto), elimina.
- **Eliminazione di un progetto** in tre passaggi: avviso con quanto si perde (elementi, trascrizioni, note); scrittura di `DELETE`; ultimo avviso. Poi crypto-shredding di tutti gli elementi del progetto e tombstone di note e progetto. Non passa dal cestino.

## Conseguenze
- Deroga a FR-21 ("Da classificare" non dipende più dalla categoria, solo dal progetto).
- L'eliminazione di un progetto è definitiva per scelta esplicita: è l'unico caso, oltre all'"Elimina definitivamente" del singolo elemento, che salta il cestino.
