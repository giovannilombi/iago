# ADR-0042 — Titles suggested by Apple's model on the Mac

- Status: accepted
- Date: 2026-10-13
- Spec references: sec. 4.2 (network), 3.16 (decisions), 7.7 (voice notes); FR-150; user request

## Context
A note or a dictated passage becomes a decision with a title and description. Until now the title was the first sentence of the text, also repeated in the description, and the result was hard to read. The local LLM arrives with Phase 3 (localhost). The Apple Intelligence model, on the other hand, is already in the system, runs on the Mac, and supports Italian.

## Decision
- **Generator:** `IAGOIntelligence/TitleSuggester` uses the **Foundation Models** framework, that is the on-device Apple Intelligence model. It suggests a title of at most 8 words, in the language of the text.
- **When it steps in:** only when a long text (more than 90 characters) becomes a decision. The full text goes into the description, and the suggested title stays editable, marked with ✨.
- **Fallback:** if Apple Intelligence is off or unavailable, or the model refuses, the title stays empty with the first sentence as a placeholder. If the user leaves it empty, that sentence is used.
- **Network and privacy:**
  - The model runs in-process, on the Mac, with no network calls, so it is not an exception to sec. 4.2, and the automatic check stays unchanged.
  - The text is never written to the logs.
- **Compatibility:** `#if canImport(FoundationModels)` and `#available(macOS 26, *)`, so on earlier systems only the fallback remains.

## Consequences
- More concise titles without downloading models and without paid services.
- Quality depends on Apple's model. The title is always a suggestion, never saved without the user seeing the editor.
- The same generator could serve in Phase 3 for call and email titles. Real summaries remain with the local LLM.
