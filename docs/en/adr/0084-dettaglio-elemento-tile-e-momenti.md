# ADR-0084 — Item detail: tiles, sticky bar and moments

- Status: accepted (1.2.11-beta); order of the sections revised in ADR-0088
- Date: 2026-11-02
- References: ADR-0018 (the item is a typed event), ADR-0049 («Ask IAGO» at the bottom right), ADR-0072 (mark moment with screenshot); internal review board of 2026-11-02, prototype approved by the user

## Context
- The detail of a call is long: summary, key points, suggestions, notes, player, bookmarks, screenshots, transcript, links, files.
- Sections are already collapsible (`SectionBox`) and long transcripts have a maximum height. But the open/closed state applies per section type across the whole app, and whoever opens an item cannot see at a glance what it contains.
- Bookmarks and screenshots live in separate sections: in the transcript screenshots appear as a text row, bookmarks do not. The player does not show where the moments are.
- Empty sections take the same space as full ones.

## Decision
- **Small tiles under the title**, low and wide, wrapping on their own, a single group:
  - each tile has the section name and one value only: the number of entries, «✓» for the summary;
  - the **Transcript** tile names the source in full: «IAGO», «Teams» or «IAGO + Teams»; «…» while in progress, «—» if there is none. For emails and documents: «Email ✓» or «Content ✓»;
  - an empty tile is dashed and grey;
  - a click opens the section and scrolls to it.
- **Under the title**, client › project on one line and date · duration · type on the next.
- **Sticky bar on scroll:** when the tiles leave the screen a translucent bar appears at the top with the title, then client › project · date · duration on a new line, and the tiles in miniature with the current section highlighted. Back at the top it disappears.
- **Back to top:** a round ↑ button at the bottom right, above «Ask IAGO» at a fixed distance; if «Ask IAGO» is hidden, the ↑ takes its place. It appears only with the sticky bar.
- **Open or closed per item:** each item remembers the sections opened and closed inside it. The starting point of each section is chosen in Settings › General › Item detail, with «Reapply to all items…» to forget the choices made in single items. **Files** is always open and sits at the bottom.
- **Empty sections reduced to their header:** dashed and grey, no chevron, with their own sentence («No links to other items») and, when useful, the action (for example «Link…»).
- **Player with moments:**
  - on the player a tick for each bookmark and screenshot, in their colour;
  - below, one moment at a time (thumbnail, kind, title, minute) with ‹ › and «N of M». On opening it is the next one after the current position, while listening it follows the audio; a click on a tick selects it;
  - fixed height, no horizontal scrolling, never empty; without moments only the player remains.
- **Moments in the transcript:** bookmarks and screenshots appear at their minute, in their colour. They can be turned off in Settings, like the ticks on the player.

## Consequences
- The open/closed state moves from a preference per section type to one per item, with defaults in Settings: the global choices made so far become the new defaults.
- The sticky bar and the ↑ require reading the scroll position of the detail (macOS 15). The ↑ sits in the same layer as «Ask IAGO», so the two never overlap.
- The guide (in Italian and English) and its screenshots must be redone for the item detail.
- The Bookmarks and Screenshots sections stay: tiles, player and transcript are other ways to reach them.
