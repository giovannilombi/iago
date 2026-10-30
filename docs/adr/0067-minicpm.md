# ADR-0067 — MiniCPM: al posto di Qwen 3.5 4B o in aggiunta

- Stato: rifiutato (decisione dell'utente del 2026-10-30: MiniCPM non entra nel catalogo)
- Data: 2026-10-24
- Riferimenti: ADR-0048 (motore locale MLX, catalogo dei modelli), ADR-0054 (sintesi, minimo 9B)

## Contesto
- Il catalogo del motore locale oggi offre Qwen 3.5 4B, Qwen 3.5 9B e Gemma 4 12B, più Qwen3 Embedding 0.6B per la ricerca.
- Qwen 3.5 4B è il modello leggero (Mac da 8-16 GB): va bene per "Riordina testo", proposte e Chiedi, ma è stato escluso dalle sintesi perché troppo debole (ADR-0054).
- L'utente ha trovato **MiniCPM**, una famiglia di modelli piccoli che potrebbe fare meglio nella stessa fascia di memoria.

## Le due strade
1. **Sostituire** Qwen 3.5 4B con MiniCPM: catalogo più semplice, un solo modello leggero.
2. **Aggiungere** MiniCPM accanto ai modelli attuali: più scelta, ma un modello in più da mantenere e da spiegare.

## Cosa va verificato prima di scegliere
- **Versione e formato:** quale MiniCPM (dimensione, variante solo testo), se esiste una conversione MLX affidabile e se gira con il nostro adattatore MLX senza modifiche.
- **Licenza:** compatibile con la distribuzione gratuita di IAGO (CC BY-NC-SA) e con il download dentro l'app; va letta e registrata in `docs/licenses.md`.
- **Qualità in italiano**, con le prove già usate per il catalogo (`-IAGOEngineBench`):
  - Riordina testo: nessun numero o nome perso;
  - proposte: JSON valido e titoli sensati;
  - Chiedi: risposte con le fonti giuste;
  - sintesi: se arriva vicino al 9B, si può rivedere il minimo di ADR-0054.
- **Velocità e memoria** su un Mac da 16 GB e su uno da 8 GB, a confronto con Qwen 3.5 4B.
- **Download:** dimensione, URL fisso e SHA-256 (regola di rete n. 1).

## Decisione
Da prendere dopo le prove. Se MiniCPM è migliore di Qwen 3.5 4B su qualità e affidabilità del JSON a parità di memoria, lo sostituisce; se è migliore solo in alcuni compiti, si aggiunge; se no, si scarta.
