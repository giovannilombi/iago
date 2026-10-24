# Licenze e crediti

IAGO: © 2026 Giovanni Lombi, licenza **CC BY-NC-SA 4.0** (`LICENSE`, ADR-0034).

Ogni dipendenza ha la versione fissata ed è stata verificata alla versione usata. Nessuna fa telemetria. Licenze controllate sui repository il 2026-10-21.

## Librerie
| Libreria | Uso in IAGO | Versione | Licenza |
|---|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | archivio SQLite, migrazioni, ricerca a testo pieno | 7.11.1 | MIT |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | trascrizione Whisper con Metal | 1.9.2 (xcframework ufficiale) | MIT |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | Parakeet, VAD Silero, diarizzazione | 0.17.7 | Apache-2.0 |
| [MLX Swift](https://github.com/ml-explore/mlx-swift) e [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) | motore locale (modelli linguistici ed embedding) | 0.32.3 / 3.32.3 | MIT |
| [swift-transformers](https://github.com/huggingface/swift-transformers) | tokenizer | 1.3.4 | Apache-2.0 |
| [swift-huggingface](https://github.com/huggingface/swift-huggingface), [swift-jinja](https://github.com/huggingface/swift-jinja) | dipendenze dei tokenizer (formato dei file, template di chat) | 0.13.0 / 2.5.1 | Apache-2.0 |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | aggiornamenti firmati EdDSA (ADR-0056) | 2.10.0 | MIT (più gli avvisi dei componenti esterni nel suo LICENSE) |
| [yyjson](https://github.com/ibireme/yyjson) | lettura JSON (dipendenza di MLX Swift LM) | 0.12.0 | MIT |
| [EventSource](https://github.com/mattt/EventSource) | dipendenza di swift-huggingface; IAGO non la usa per connettersi | 1.5.1 | MIT |
| [swift-collections](https://github.com/apple/swift-collections), [swift-numerics](https://github.com/apple/swift-numerics), [swift-crypto](https://github.com/apple/swift-crypto), [swift-asn1](https://github.com/apple/swift-asn1), [swift-syntax](https://github.com/swiftlang/swift-syntax) | librerie di base del linguaggio | 1.7.3 · 1.1.1 · 4.5.2 · 1.7.3 · 603.0.2 | Apache-2.0 |

## Modelli
Si scaricano solo su richiesta dell'utente, da indirizzi fissati a un commit, con verifica SHA-256 di ogni file.

| Modello | Uso | Fonte | Licenza |
|---|---|---|---|
| Whisper large-v3-turbo (ggml) | trascrizione | huggingface.co/ggerganov/whisper.cpp | MIT |
| Parakeet TDT 0.6B v3 (CoreML) | trascrizione veloce | huggingface.co/FluidInference | CC-BY-4.0 |
| Silero VAD (CoreML) | riconoscere dove si parla | huggingface.co/FluidInference | MIT |
| pyannote / WeSpeaker (CoreML) | chi parla | huggingface.co/FluidInference | licenze dei modelli originali |
| Qwen 3.5 4B e 9B (MLX, 4 bit) | motore locale | mlx-community | Apache-2.0 |
| Gemma 4 12B (MLX, 4 bit) | motore locale | mlx-community | Gemma Terms of Use |
| Qwen3 Embedding 0.6B (MLX) | ricerca per significato | mlx-community | Apache-2.0 |
| Apple Foundation Models | solo i titoli proposti | macOS | modello di sistema di Apple |

## Idee e modelli di sintesi
| Progetto | Cosa viene da lì | Licenza |
|---|---|---|
| [Meetily](https://github.com/Zackriya-Solutions/meeting-minutes) | formato JSON dei modelli di sintesi e alcuni modelli, adattati (ADR-0054) | MIT, © 2024 Zackriya Solutions |
| [Hyprnote / Anarlog](https://github.com/fastrepl/hyprnote) | sezioni dei modelli di sintesi, adattate (ADR-0054) | MIT, © 2023-present Fastrepl, Inc. |
| AudioCap (esempio di Apple) | consultato per il process tap dell'audio di sistema | nessun codice copiato |
