# LFM2.5 models test — 2026-11-06

The user's Mac (36 GB). These are the same three real calls as the [October 21 test](2026-10-21-sintesi-e-glossario), about 30 minutes each. Only measurements and observations here, no call content. The decisions taken are in ADR-0096.

## Summaries (`-IAGOSummaryBench`)
| Call | Summary template | Qwen 3.5 9B | LFM2.5 8B-A1B, with reasoning | LFM2.5 8B-A1B, reasoning skipped |
|---|---|---|---|---|
| Pension fund consultation | Client/Sales | 123 s · 35 points (7 discarded) | 227 s · 0 points | 38 s · 11 points (19 discarded) |
| Proposal preparation | Standard | 85 s · 13 points | 189 s · 2 points (3 discarded) | 95 s · 3 points (60 discarded) |
| Internal meeting | Standard | 73 s · 10 points | 183 s · 3 points (6 discarded) | 97 s · 1 point (107 discarded) |

**With reasoning**, the model always reasons before answering:
- it produced 52-69 thousand characters of reasoning per call;
- in many blocks it ran out of tokens (the request plus 4,096 for the reasoning) before reaching the answer, so the answer was empty.

**With reasoning skipped**, that is with an empty `<think></think>` block already placed at the start of the answer:
- it answers at once, and on the first call it is 3 times faster than Qwen 3.5 9B;
- but it copies spoken sentences instead of summarising them, and repeats them: of 186 discarded points, 160 were copied sentences, 14 had a quote that was not in the call and 12 were duplicates.

**Peak GPU memory:** 5.1 GB with reasoning skipped, 5.7-6.9 GB with reasoning; Qwen 3.5 9B 5.7-6.9 GB. With long calls the memory advantage therefore shrinks.

**LFM2.5 24B-A2B** (first call):
- **Time and result:** every block hits the token limit in about 113 s and writes 20-40 thousand characters of reasoning in plain text, without the requested format. The total is 347 s for one call, with 0 points.
- **What was tried:**
  - its chat template already opens `<think>`, so only `</think>` goes in front of the answer;
  - the same, without the repetition penalty: no change.
- **Comparison:** Gemma 4 12B does the same call in about 275 s, and on October 21 it had found 31 points.

## Suggestions and «Tidy up text» (`-IAGOEngineBench`, internal meeting)
| Model | Suggestions | Kept / discarded | Tidying the 3 passages | Peak memory |
|---|---|---|---|---|
| Qwen 3.5 4B | 40 s | 2 / 1 | 10-11 s | 3.35 GB |
| Qwen 3.5 9B | 59 s | 1 / 1 | 19-21 s | 6.09 GB |
| Gemma 4 12B | 179 s | 7 / 2 | 41-46 s | 12.45 GB |
| LFM2.5 8B-A1B | 32 s | 5 / 22 | 4-5 s | 6.08 GB |

- The 8B-A1B is the fastest, but of 27 suggestions 25 were discarded: 22 for a quote that was not in the call.
- **Tidy up text:**
  - the 8B-A1B is twice as fast as the 4B, but in one passage it lost four facts, one of them a figure;
  - the other models lost one or two per passage.

## Conclusions
**The two models do not enter IAGO** (ADR-0096, rejected). The code used for the test does not stay in the app:
- **catalog:** the models were in the *experimental* group, with a pinned commit and SHA-256;
- **reasoning:** IAGO removed it from the answers;
- **prefix:** `<think></think>` went in front of the answer, or only `</think>` for the 24B, whose chat template already opens the block;
- **tokens:** it added 4,096 for the reasoning.

Reasons and lessons:
- **The 8B-A1B** is fast but does not summarise, and many of its suggestions quote sentences that do not exist. Its only advantage is a quick *Tidy up text*, which however lost facts: not enough to keep it.
- **The 24B-A2B** gave no usable summary and is slower than Gemma 4 12B.
- **For 16 GB Macs Qwen 3.5 9B stays**, with Claude as an alternative for summaries.
- **To be tried again** with a new version of MLX Swift or of the models, or with instructions designed for them. Two points in particular:
  - a documented way to turn the reasoning off;
  - the quality of the Italian.
