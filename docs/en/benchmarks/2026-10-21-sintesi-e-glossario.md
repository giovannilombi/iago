# Test of summaries and glossary — 2026-10-21

The user's Mac (36 GB). Real calls of about 30 minutes; here only measurements and observations, no content from the calls.

## Summaries (ADR-0054), after the fixes
| Call | Summary template | Qwen 3.5 9B | Gemma 4 12B |
|---|---|---|---|
| Pension fund consulting | Client/Sales | 97 s · 17 points | 272 s · 31 points |
| Proposal preparation | Standard | 64 s · 10 points | 167 s · 19 points |
| Internal meeting | Standard | 87 s · 11 points | 161 s · 10 points |

- Qwen 3.5 4B: 26-38 s, but from 1 to 8 points; not suitable for summaries.
- Gemma: figures, due dates and names correct in the points checked. The remaining errors are of meaning:
  - an anecdote presented as a decision;
  - a personal fact ending up in the highlights;
  - a "cautious" in place of "dynamic".

  Two rules were added: no personal facts, and the decisions are only those made in the meeting.
- **Problems found and fixed during the test:**
  - the model copied the spoken sentence instead of summarizing it;
  - JSON that was too long got truncated;
  - Gemma closes brackets badly or inserts `","` at random.

  Now the parsing is tolerant: section by section, and by patterns if the JSON can't be read.

## Transcription glossary (Whisper)
- **65-minute call, with and without glossary:** no glossary word appears at random, discarded hallucinations go down from 4 to 2, glossary terms are spelled correctly a little more often.
- **Synthetic sentence with four difficult company names:** two correct, two still wrong (mispronounced by the synthetic voice), and "kick-off" got worse.

It helps, but doesn't solve everything: it needs to be checked on real calls.
