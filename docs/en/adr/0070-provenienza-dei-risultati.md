# ADR-0070 — Who produced each result

- Status: accepted
- Date: 2026-10-27
- References: ADR-0048 (local engine and models), ADR-0049 (suggestions and Ask), ADR-0054 (summaries), ADR-0071 (summaries and suggestions written by Claude); user's directions of 2026-10-27

## Context
- The quality of a summary or a suggestion depends on the model: a 4B finds fewer than a 9B (tests of 2026-10-16 and 2026-10-21).
- IAGO saved the model for summaries, suggestions and Ask answers, but showed it only for summaries and answers; for key points confirmed from a suggestion it was lost.
- With ADR-0071 summaries and suggestions can also come from Claude: where they come from must be stated.

## Decision
- **Every result says who produced it**, with the same line everywhere:
  - summaries: «Summarized with Qwen 3.5 9B on the Mac» or «Summarized by Claude»;
  - suggestions: «Suggested by Qwen 3.5 4B on the Mac» or «Recommended by Claude»;
  - key points confirmed from a suggestion: «Suggested by Qwen 3.5 4B on the Mac, confirmed by you» or «Recommended by Claude, confirmed by you»;
  - Ask answers: the model name, as today.
- **For the local engine the model matters**: next to a result from a model below 9B, «small model» appears, with the hint to use a larger one. **For Claude it is enough to know it is Claude**: the MCP server does not know which Claude model is calling it, it only knows the app (for example Claude Desktop), which is saved as information.
- **Data** (migration `v18-provenance`):
  - `summary.origin` and `suggestion.origin`: `engine` or `claude` (default `engine`, for everything that already existed);
  - `decision.model`: the catalog model id, or `claude`, for key points confirmed from a suggestion;
  - `model` remains the catalog id; the name is read from the catalog and, if a model disappears, the id is shown.
- A new engine run replaces only its **own** pending suggestions: it does not delete Claude's, and vice versa.

## Consequences
- The user always knows how much to trust a result and understands when a larger model is worthwhile.
- Notes and key points written by hand have no model: they are not produced by an engine.
