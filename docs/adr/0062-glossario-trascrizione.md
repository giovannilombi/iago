# ADR-0062 — Glossario della trascrizione

- Stato: accettato
- Data: 2026-10-21
- Riferimenti spec: sez. 7 (trascrizione); ADR-0023; memoria "qualità della trascrizione"; prova del 2026-10-21 (`docs/benchmarks/2026-10-21-sintesi-e-glossario.md`)

## Contesto
Le trascrizioni reali sbagliano soprattutto i nomi: aziende, sigle, persone. Questi errori finiscono anche in sintesi e punti chiave.

## Decisione
- **Il glossario:**
  - **Impostazioni › Trascrizione › Glossario**: nomi e termini separati da virgole;
  - per ogni call IAGO aggiunge da solo progetto, cliente, stream e contatti del progetto.
- **Whisper** riceve il glossario come *initial prompt*:
  - termini unici, al massimo circa 200 caratteri, perché un testo lungo fa ripetere a Whisper il prompt nei silenzi;
  - in `TranscriptionOptions.vocabulary` e `vocabularyPrompt`.
- **Parakeet** per ora non lo usa (FluidAudio ha un sistema diverso, da valutare).
- `iago-bench --vocabulary` serve per confrontare con e senza glossario.

## Conseguenze
- **Esito della prova:**
  - su una call di 65 minuti non ha inventato niente e ha scartato meno allucinazioni (da 4 a 2);
  - su una frase sintetica ha corretto 2 nomi su 4.

  Aiuta, ma non è risolutivo: resta in lista la prova approfondita della trascrizione.
