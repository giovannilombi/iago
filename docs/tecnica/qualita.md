# Qualità e misure

## Test automatici
235 test nei pacchetti, con Swift Testing, tutti verdi a ogni PR:

| Pacchetto | Test |
|---|---|
| IAGOStore | 80 |
| IAGOCapture | 48 |
| IAGOTranscription | 28 |
| IAGOIngest | 19 |
| IAGOIntelligence | 17 |
| IAGOMCP | 16 |
| IAGOCore | 15 |
| IAGOExport | 7 |
| IAGOEngine | 4 |
| IAGOSync | 1 |

- La pipeline audio usa fixture **sintetiche** (voci `say`), mai registrazioni reali.
- Il motore MLX si prova con `scripts/test-engine.sh` e con il banco `-IAGOEngineBench`.

## Prove manuali
- [Prove per i tester](/prove-tester): l'elenco ordinato, pensato per chi non conosce l'app.
- Ogni tester ha una issue su GitHub con le prove come caselle; i problemi diventano issue separate.

## Misure
- [Trascrizione, fase 0](/benchmarks/2026-10-phase0): whisper e Parakeet su 2 h 44 min di call reali.
- [Sintesi e glossario](/benchmarks/2026-10-21-sintesi-e-glossario): Qwen 9B e Gemma 12B su call reali, glossario di Whisper.

Le misure riportano solo numeri e osservazioni: i contenuti delle call restano sul Mac di chi le ha fatte.

## Storia dello sviluppo
- [Fase 0](/phase-0): cattura su due tracce e prova dei motori di trascrizione.
- [Fase 1](/phase-1): archivio, trascrizione, organizzazione, configurazione guidata.
- [Fase 2](/phase-2): ricerca, decisioni, gerarchia, note, email, esportazioni.
- [Fase 3](/phase-3): Claude via MCP, motore locale, ricerca per significato, proposte, Chiedi, sintesi.
