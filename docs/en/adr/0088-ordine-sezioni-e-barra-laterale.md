# ADR-0088 — Order of the item's sections and sidebar

- Status: accepted
- Date: 2026-11-03
- References: ADR-0084 (item detail), ADR-0038 (client › project › stream), ADR-0087 (columns per place); requests of the user of 2026-11-03

## Context
- In the item detail the summary and the suggestions came before the audio, and the transcript came after bookmarks and screenshots: whoever opens a call wants to listen to it first and find the marked moments.
- A fixed order does not suit everyone: some look at the summary first, others at the notes.
- In the sidebar the **＋** for a new project or client was at the bottom left, far from the projects. On a client's header the arrow and the **+** did not respond to the click, and the new project window never opened, like the new stream one.
- With a narrow sidebar, long project names can only be read by opening them.
- The line between the middle and right columns crossed the toolbar at the top.

## Decision
- **Standard order of the sections:** Audio, Bookmarks, Screenshots, Summary, Transcript (or Email and Content), Suggestions, Key points, Notes, Links, Files. The tiles follow the same order.
- **Order chosen by the user:** on the right of each section's title there is a discreet handle (≡). The title is dragged:
  - every section shows only its header and a sentence at the top explains what to do;
  - the dragged section is highlighted and the others move as it passes;
  - on drop the sections go back to open or closed as before.
- The order is **one for every item**, kept between launches. Settings › General › Item detail › *Restore the section order* goes back to the standard one. Audio and Files are always open, but move like the others.
- **Sidebar:**
  - no «Projects» title: above clients and projects, on the right, there is **Add**, with the menu *Add:* › *Client…*, *Project…*;
  - at the bottom only the **Trash** remains, as a row like the views at the top;
  - on a client's header the **+** remains, opening the new project with that client already chosen and not editable. The arrow goes: the client opens with right-click › *Open*;
  - after **two seconds** on a project's name the whole name appears.
- **Whole toolbar:** the divider between the middle and right columns stops under the toolbar, which stays one piece with only the sidebar's line.

## Consequences
- The order is in `detail.sectionOrder`; the demo tour neither reads nor writes it. A new section the saved order does not know takes its standard place.
- The new project and new stream windows are shown by the main window (`AppModel.newProject`, `newStreamProject`): inside the sidebar's list they never appeared.
- The divider is shortened with a mask on its view (`ContentColumnWidth`), because SwiftUI's split view does not let you choose which columns run under the toolbar.
- The guide (chapters 06, 07 and 16, in Italian and English) describes the changes; the screenshots are retaken when the design is stable.
