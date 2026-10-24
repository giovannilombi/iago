# Trascrizione

Tutto avviene sul Mac (ADR-0005), nella coda dei lavori, un elemento alla volta.

## Pipeline
1. **Decodifica** delle tracce e ricampionamento a 16 kHz mono.
2. **VAD** Silero (via FluidAudio) e divisione in blocchi di parlato (ADR-0006).
3. **Riconoscimento** con il motore scelto.
4. **Diarizzazione** pyannote/WeSpeaker (FluidAudio) sulla traccia di sistema; la traccia del microfono è "Io". Più persone nella stessa stanza si separano anche sul microfono (ADR-0031).
5. **Segmentazione per speaker:** tempi per parola di whisper, segmenti divisi ai cambi di speaker e frasi spezzate ricucite.
6. **Unione** delle due tracce sulla linea del tempo e **filtro dell'eco:** le frasi del microfono che ripetono quelle della traccia di sistema vengono scartate.
7. **Indicizzazione** dei segmenti per la ricerca.

## Motori (ADR-0023)
| Motore | Implementazione | Velocità misurata | Note |
|---|---|---|---|
| **Whisper large-v3-turbo** (predefinito) | whisper.cpp 1.9.2, Metal, beam search 5, italiano forzato | 19× il tempo reale | più preciso su nomi e termini inglesi |
| **Parakeet TDT 0.6B v3** | FluidAudio, CoreML sul Neural Engine | 87× il tempo reale | più veloce, più errori sui nomi |

- La diarizzazione impiega pochi secondi per call (circa 300× il tempo reale).
- Misure su 2 h 44 min di call reali, M3 Pro: [benchmark fase 0](/benchmarks/2026-10-phase0).
- I modelli (circa 1,6 GB) si scaricano su richiesta da URL fissi con verifica SHA-256.

## Glossario (ADR-0062)
- Nomi di persone, clienti e termini del progetto diventano il **prompt iniziale** di Whisper (al massimo 200 caratteri).
- Parakeet non ha un prompt: il glossario vale solo per Whisper.
- Misura: [sintesi e glossario](/benchmarks/2026-10-21-sintesi-e-glossario).

## Strumenti
- `iago-bench` (pacchetto `IAGOTranscription`) confronta motori e opzioni su file audio locali; i risultati restano in `bench-out/`, mai nel repository.
- Le fixture dei test sono sintetiche (`scripts/make-fixtures.sh`, voci `say`).
