# Prova dei modelli LFM2.5 — 2026-11-06

Mac dell'utente (36 GB). Sono le stesse tre call reali della [prova del 21 ottobre](2026-10-21-sintesi-e-glossario), di circa 30 minuti ciascuna. Qui ci sono solo misure e osservazioni, nessun contenuto delle call. Le decisioni prese sono nell'ADR-0096.

## Sintesi (`-IAGOSummaryBench`)
| Call | Modello di sintesi | Qwen 3.5 9B | LFM2.5 8B-A1B, con ragionamento | LFM2.5 8B-A1B, ragionamento saltato |
|---|---|---|---|---|
| Consulenza fondo pensione | Client/Sales | 123 s · 35 punti (7 scartati) | 227 s · 0 punti | 38 s · 11 punti (19 scartati) |
| Preparazione proposta | Standard | 85 s · 13 punti | 189 s · 2 punti (3 scartati) | 95 s · 3 punti (60 scartati) |
| Riunione interna | Standard | 73 s · 10 punti | 183 s · 3 punti (6 scartati) | 97 s · 1 punto (107 scartati) |

**Con il ragionamento** il modello ragiona sempre prima di rispondere:
- ha prodotto 52-69 mila caratteri di ragionamento per call;
- in molti blocchi ha esaurito i token (la richiesta più 4.096 per il ragionamento) senza arrivare alla risposta, quindi con risposta vuota.

**Con il ragionamento saltato**, cioè con un blocco `<think></think>` vuoto già messo all'inizio della risposta:
- risponde subito, e sulla prima call è 3 volte più veloce di Qwen 3.5 9B;
- però le frasi del parlato le copia invece di riassumerle, e le ripete: su 186 punti scartati, 160 erano frasi copiate, 14 avevano una citazione che nella call non c'era e 12 erano doppioni.

**Memoria GPU di picco:** 5,1 GB con il ragionamento saltato, 5,7-6,9 GB con il ragionamento; Qwen 3.5 9B 5,7-6,9 GB. Con call lunghe il vantaggio di memoria quindi si riduce.

**LFM2.5 24B-A2B** (prima call):
- **Tempo e risultato:** ogni blocco arriva al limite di token in circa 113 s e scrive 20-40 mila caratteri di ragionamento in chiaro, senza il formato richiesto. Il totale è 347 s per una call, con 0 punti.
- **Cosa è stato provato:**
  - il suo modello di conversazione apre già `<think>`, quindi davanti alla risposta va solo `</think>`;
  - lo stesso, senza penalità di ripetizione: nessun cambiamento.
- **Confronto:** Gemma 4 12B fa la stessa call in circa 275 s, e il 21 ottobre aveva trovato 31 punti.

## Proposte e «Riordina testo» (`-IAGOEngineBench`, riunione interna)
| Modello | Proposte | Tenute / scartate | Riordino dei 3 passaggi | Memoria di picco |
|---|---|---|---|---|
| Qwen 3.5 4B | 40 s | 2 / 1 | 10-11 s | 3,35 GB |
| Qwen 3.5 9B | 59 s | 1 / 1 | 19-21 s | 6,09 GB |
| Gemma 4 12B | 179 s | 7 / 2 | 41-46 s | 12,45 GB |
| LFM2.5 8B-A1B | 32 s | 5 / 22 | 4-5 s | 6,08 GB |

- L'8B-A1B è il più veloce, ma su 27 proposte 25 sono state scartate: 22 per una citazione che nella call non c'era.
- **Riordina testo:**
  - l'8B-A1B è 2 volte più veloce del 4B, ma in un passaggio ha perso quattro fatti, tra cui una cifra;
  - gli altri modelli ne hanno persi da uno a due per passaggio.

## Conclusioni
**I due modelli non entrano in IAGO** (ADR-0096, rifiutato). Il codice usato per la prova non resta nell'app:
- **catalogo:** i modelli erano nel gruppo *sperimentali*, con commit fisso e SHA-256;
- **ragionamento:** IAGO lo toglieva dalle risposte;
- **prefisso:** davanti alla risposta andava `<think></think>`, o solo `</think>` per il 24B, il cui modello di conversazione apre già il blocco;
- **token:** ne aggiungeva 4.096 per il ragionamento.

Motivi e lezioni:
- **L'8B-A1B** è veloce ma non riassume, e molte sue proposte citano frasi inesistenti. L'unico vantaggio è un *Riordina testo* rapido, che però ha perso dei fatti: non basta per tenerlo.
- **Il 24B-A2B** non ha dato nessuna sintesi utilizzabile ed è più lento di Gemma 4 12B.
- **Per i Mac con 16 GB resta Qwen 3.5 9B**, e Claude come alternativa per le sintesi.
- **Da riprovare** con una versione nuova di MLX Swift o dei modelli, o con istruzioni pensate per loro. Due punti in particolare:
  - un modo documentato per spegnere il ragionamento;
  - la qualità dell'italiano.
