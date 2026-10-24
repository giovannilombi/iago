# ADR-0006 — VAD e diarizzazione con FluidAudio

- Stato: accettato
- Data: 2026-10-11
- Riferimenti spec: sez. 7.1, 7.2, 17.6

## Contesto
Servono VAD (per limitare l'ASR alle regioni di parlato e ridurre le allucinazioni di Whisper) e diarizzazione. Le opzioni valutate sono FluidAudio (Swift/CoreML, Neural Engine) e sherpa-onnx (C++/ONNX).

## Decisione
FluidAudio per VAD e diarizzazione. Nelle registrazioni la diarizzazione si applica **solo** alla traccia sistema (la traccia mic è "Io"); negli import a tutto l'audio.

## Conseguenze
- Integrazione Swift nativa via SPM, esecuzione su Neural Engine.
- Dipendenza da un progetto relativamente giovane: versione fissata, licenza in `docs/licenses.md`.
