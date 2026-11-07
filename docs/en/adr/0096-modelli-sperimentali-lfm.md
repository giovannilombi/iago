# ADR-0096 — LFM2.5 8B-A1B and 24B-A2B models: tested and not integrated

- Status: rejected
- Date: 2026-11-06
- References: ADR-0048 (local engine catalog), ADR-0054 (summaries, at least 9B), ADR-0067 (MiniCPM, rejected); [test of 2026-11-06](../benchmarks/2026-11-06-modelli-lfm.md); user request of 2026-11-06

## Context
- On 16 GB Macs the only model that writes summaries is Qwen 3.5 9B: about 6 GB of memory, and the Mac slows down while it works. The priority is to serve users with little memory better.
- Liquid AI has released two "mixture of experts" models, which use only part of their parameters for each word:

  | Model | Parameters | Active per word | 4-bit weight |
  |---|---|---|---|
  | LFM2.5 8B-A1B | 8.3 billion | 1.5 billion | 4.8 GB |
  | LFM2.5 24B-A2B | 24 billion | about 2.4 billion | 13.6 GB |

  According to the maker's tests they follow instructions well and make up less than models of the same size. They exist in official MLX versions, and the `lfm2_moe` architecture is already in the MLX Swift version we use.
- **Against:**
  - they always reason before answering, and there is no documented way to turn the reasoning off;
  - there are no published tests in Italian;
  - the *LFM Open License v1.0* allows free commercial use only below USD 10 million of annual revenue.
- **The test:** to measure them, they were added to the catalog as experimental models. IAGO removed the reasoning from the answers or tried to skip it with an empty `<think>` block. They were tested on the same three calls as the October 21 test.

## The test
The details are in [docs/en/benchmarks/2026-11-06-modelli-lfm.md](../benchmarks/2026-11-06-modelli-lfm.md).

**LFM2.5 8B-A1B:**
- **summaries with reasoning:** 183-227 s per call and 0-3 points, against 73-123 s and 10-35 points for Qwen 3.5 9B. The reasoning uses up the tokens and often no answer is left;
- **summaries with reasoning skipped:** it is fast (38 s on the first call), but it copies speech instead of summarising it: 1-11 points kept and 186 discarded;
- **suggestions:** done in 32 s, the best time in the catalog, but 22 out of 27 quoted sentences that were not in the call;
- **Tidy up text:** in 5 s, but in one passage it lost four facts;
- **peak memory:** 5-6 GB, a little less than Qwen 3.5 9B.

**LFM2.5 24B-A2B:** it reasons in plain text up to the token limit even when the reasoning is skipped, and also without the repetition penalty. It took 347 s for one call, with no summary point; Gemma 4 12B does the same call in about 275 s.

## Decision
- The two models **do not enter the catalog**, not even as experimental: for IAGO's features they deliver less than the models already there.
- The code written for the test does not stay in the app:
  - the *Experimental models* group;
  - the handling of the reasoning;
  - the «· experimental» mark.
- **For 16 GB Macs**, Qwen 3.5 9B remains for summaries, with Claude as the alternative (ADR-0095).

## Consequences
- The catalog and the app stay as they were.
- The test stays documented, so that it is not repeated the same way.
- If worthwhile, they are tried again with a new version of the models or of MLX Swift, or once there is a documented way to turn the reasoning off:
  - the test is redone on the same calls, with `-IAGOSummaryBench` and `-IAGOEngineBench`;
  - handling of the reasoning starts again from the description in the test.
