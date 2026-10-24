# ADR-0023 — Motore ASR di default: whisper.cpp large-v3-turbo

- Stato: accettato (2026-10-12, dopo la valutazione dell'utente)
- Data: 2026-10-11
- Riferimenti spec: sez. 7.1, 17.B; ADR-0005; `docs/benchmarks/2026-10-phase0.md`

## Contesto
La spec lascia aperta la scelta del motore di default tra whisper.cpp e Parakeet (FluidAudio) fino al benchmark della fase 0 su call reali. Il benchmark su 5 call reali (164 min, M3 Pro) dà whisper large-v3-turbo a 19× tempo reale e Parakeet v3 a 87×. Qualitativamente whisper è migliore su termini inglesi e nomi di prodotto, sulla punteggiatura e sui bordi dei chunk, e rende più efficace il filtro eco in trascrizione.

Valutazione dell'utente (2026-10-12): whisper è più fedele nel testo, Parakeet sembrava migliore nell'attribuzione degli speaker. La diarizzazione è la stessa per entrambi (FluidAudio): la differenza veniva dalla segmentazione. IAGO assegnava un solo speaker a ogni segmento whisper (fino a 28 s), mentre per Parakeet costruisce segmenti per frase dai tempi dei token. Benchmark pubblici su FLEURS italiano confermano il vantaggio di whisper sul testo (WER: large-v3 2,31% contro 3,00% di Parakeet v3 nel paper NVIDIA; turbo 2,77% contro 3,02% sulla classifica Handy).

## Decisione
- Default: `WhisperCppEngine` con `large-v3-turbo`, italiano forzato, beam search 5, solo sulle regioni VAD.
- Tempi per parola da whisper.cpp (`token_timestamps`). Segmentazione in due passi, comune ai motori:
  1. `splitBySpeaker`: ogni segmento whisper è diviso dove cambia lo speaker, assegnato parola per parola; i tratti più brevi di 1,5 s sono fusi nel vicino e il taglio si aggancia alla punteggiatura entro 2 parole (diarizzazione e tempi di parola sono imprecisi ai bordi);
  2. `joinSentences`: i segmenti consecutivi dello stesso speaker vengono uniti se la frase non è finita (pausa ≤ 0,8 s, durata ≤ 20 s).
  Ricucire le frasi prima di dividere per speaker spostava i tagli di 1–2 parole: l'ordine è vincolante.
- Allineamento DTW di whisper.cpp provato (opzione `alignedWords`): non più preciso dei tempi euristici su voci sintetiche (ritardo costante ~0,2 s) e incompatibile con flash attention; non usato.
- Alternativa selezionabile nelle impostazioni: `ParakeetEngine` v3 ("trascrizione veloce").
- VAD e diarizzazione restano FluidAudio per entrambi (ADR-0006).

## Conseguenze
- Modello da 1,6 GB da scaricare in onboarding; trascrizione di 1 ora in ~3 min su M3 Pro.
- Parakeet resta disponibile senza cambiare la pipeline (protocollo `TranscriptionEngine`).
- Rifinitura della segmentazione possibile in fase 2 senza cambiare motore (parametri `minSpeakerRun`, pausa, durata massima).
- Da rivalutare se esce un modello Parakeet multilingue più accurato (es. `ultra`, non ancora testato) o con registrazioni a due tracce.
