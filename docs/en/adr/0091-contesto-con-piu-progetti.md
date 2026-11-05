# ADR-0091 — "Ask IAGO" context with several projects

- Status: accepted
- Date: 2026-11-05
- References: ADR-0017 (labelled context), ADR-0049 (semantic search, suggestions and chat), ADR-0038 (client › project › stream); user request of 2026-11-05

## Context
- The *Ask IAGO* context followed the open place: a project, a client, a stream or the whole memory. *Widen context* went up one level at a time.
- Often the question concerns two or three specific projects, perhaps of different clients: the only way was the whole memory, with noisier answers.
- The context changed by itself at every change of place, even when the user wanted to keep it.

## Decision
- **Several projects together:** a new scope, `SearchScope.projects`, with at least two projects in order. `SearchScope.chosen(_:)` picks the right form: no project is the whole memory, one is the project, two or more are the chosen projects. Search, passages for the answer, new material, key point suggestions and key points in answers all follow it.
- **Context strip** at the top of the chat: a chip for each project, with the ✕ to remove a single project when there are more than one, and a line saying whether the context *Follows the open section* or is *Chosen by you: it stays when you change section*.
- **A single button, "Change context"**, with the menu:
  - *Add projects…*;
  - *Narrow context…*, off with a single project;
  - *Global context*, off when it is already the whole memory;
  - *Follow the open section*.
- **Choosing projects:** a small window with all the projects grouped by client, plus *No client*, with the client's checkbox, the count of chosen projects and a search field. *Narrow* starting from the whole memory begins with every project ticked.
- **The choice stays** when changing place and across launches (`chat.context`), until the user picks *Follow the open section*. The demo tour neither reads nor writes it.
- **Changing context** opens a new conversation and asks the last question again in the new context.

## Consequences
- No schema change: a conversation with several projects has `scopeKind` "projects" and the identifiers separated by commas in `scopeId`.
- *Widen context* stays to go up one level; *Change context* is for choosing precisely.
