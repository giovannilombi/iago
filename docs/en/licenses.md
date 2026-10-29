# Licenses and credits

IAGO: © 2026 Giovanni Lombi, licensed under **CC BY-NC-SA 4.0** (`LICENSE`, ADR-0034).

Every dependency has a pinned version and was verified at the version in use. None of them does telemetry. Licenses checked on the repositories on 2026-10-21.

## Libraries
| Library | Use in IAGO | Version | License |
|---|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite archive, migrations, full-text search | 7.11.1 | MIT |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | Whisper transcription with Metal | 1.9.2 (official xcframework) | MIT |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | Parakeet, Silero VAD, diarization | 0.17.7 | Apache-2.0 |
| [MLX Swift](https://github.com/ml-explore/mlx-swift) and [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) | local engine (language and embedding models) | 0.32.3 / 3.32.3 | MIT |
| [swift-transformers](https://github.com/huggingface/swift-transformers) | tokenizers | 1.3.4 | Apache-2.0 |
| [swift-huggingface](https://github.com/huggingface/swift-huggingface), [swift-jinja](https://github.com/huggingface/swift-jinja) | tokenizer dependencies (file format, chat templates) | 0.13.0 / 2.5.1 | Apache-2.0 |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | EdDSA-signed updates (ADR-0056) | 2.10.0 | MIT (plus the third-party component notices in its LICENSE) |
| [yyjson](https://github.com/ibireme/yyjson) | JSON parsing (dependency of MLX Swift LM) | 0.12.0 | MIT |
| [EventSource](https://github.com/mattt/EventSource) | dependency of swift-huggingface; IAGO does not use it to connect | 1.5.1 | MIT |
| [swift-collections](https://github.com/apple/swift-collections), [swift-numerics](https://github.com/apple/swift-numerics), [swift-crypto](https://github.com/apple/swift-crypto), [swift-asn1](https://github.com/apple/swift-asn1), [swift-syntax](https://github.com/swiftlang/swift-syntax) | core language libraries | 1.7.3 · 1.1.1 · 4.5.2 · 1.7.3 · 603.0.2 | Apache-2.0 |

## Models
Downloaded only at the user's request, from addresses pinned to a commit, with SHA-256 verification of every file.

| Model | Use | Source | License |
|---|---|---|---|
| Whisper large-v3-turbo (ggml) | transcription | huggingface.co/ggerganov/whisper.cpp | MIT |
| Parakeet TDT 0.6B v3 (CoreML) | fast transcription | huggingface.co/FluidInference | CC-BY-4.0 |
| Silero VAD (CoreML) | detecting where there is speech | huggingface.co/FluidInference | MIT |
| pyannote / WeSpeaker (CoreML) | who is speaking | huggingface.co/FluidInference | licenses of the original models |
| Qwen 3.5 4B and 9B (MLX, 4-bit) | local engine | mlx-community | Apache-2.0 |
| Gemma 4 12B (MLX, 4-bit) | local engine | mlx-community | Gemma Terms of Use |
| Qwen3 Embedding 0.6B (MLX) | semantic search | mlx-community | Apache-2.0 |
| Apple Foundation Models | suggested titles only | macOS | Apple system model |

## Ideas and summary templates
| Project | What comes from it | License |
|---|---|---|
| [Meetily](https://github.com/Zackriya-Solutions/meeting-minutes) | JSON format of the summary templates and some templates, adapted (ADR-0054) | MIT, © 2024 Zackriya Solutions |
| [Hyprnote / Anarlog](https://github.com/fastrepl/hyprnote) | sections of the summary templates, adapted (ADR-0054) | MIT, © 2023-present Fastrepl, Inc. |
| AudioCap (Apple sample) | consulted for the system audio process tap | no code copied |
