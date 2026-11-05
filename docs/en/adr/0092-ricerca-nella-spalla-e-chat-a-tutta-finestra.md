# ADR-0092 — Search in the right pane and "Ask IAGO" full window

- Status: accepted
- Date: 2026-11-05
- References: ADR-0036 (search index), ADR-0049 (semantic search and chat), ADR-0091 (context with several projects); user request of 2026-11-05

## Context
- Search lived in the field at the top right and the results took the place of the middle column; to get back to them there was the *Back to results* bar. With *Ask IAGO* open, the search field stayed visible and two ways of searching sat in two different places.
- It was not clear when to use search, which finds words, and when to ask IAGO, which answers with sources.
- During a long conversation the chat had little room, and the rest of the window was not needed.

## Decision
- **"Search" instead of the field:** in the top bar a *Search* button (⌘F) opens search in the right pane and puts the cursor in the field. It stays highlighted while search is open.
- **Simple search in the pane**, where *Ask IAGO* opens too, one at a time:
  - at the top a sentence says what it does and when to use it. With the search model downloaded it adds that it also finds passages said in other words;
  - the field, with suggestions for *#tag* and *category:*;
  - the results, with the same scope and filters as before. A click opens the item in the detail and the results stay in the pane;
  - the ✕, or Esc, closes it;
  - at the bottom the box "Need an answer, a summary or a comparison?", with *Ask IAGO*.
- **From chat to search:** in the *Ask IAGO* header a magnifying glass, *Switch to simple search*, opens search in the same pane.
- **Full window:** a button in the chat header, *Full window* or *Back to a pane*. In full window these stay:
  - the sidebar;
  - the list of conversations;
  - the conversation, at most about 760 points wide;
  - the sources, which open in a panel on the right.

  A click on a place in the sidebar leaves the full window view.
- **The conversation stays:** the chat state lives in the model (`ChatState` in `AppModel`), so it is not lost going to full window and back, nor closing and reopening the pane.
- The *Back to results* bar is gone. The floating *Ask IAGO* button hides while either pane is open.

## Consequences
- Search and answers have a single place and consistent behaviour, and each points to the other.
- Whoever wants to start over uses *New conversation*: closing the pane no longer clears the chat.
