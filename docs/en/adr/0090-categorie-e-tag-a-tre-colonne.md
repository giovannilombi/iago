# ADR-0090 — Categories and tags in three columns

- Status: accepted
- Date: 2026-11-05
- References: ADR-0054 (summaries by category), ADR-0063 (sidebar and cross-cutting access), ADR-0087 (columns per place); user request of 2026-11-05 (variant B)

## Context
- *Categories and tags* showed the labels and the items in a single column, with the detail in the right panel of the wide view: with many tags the list grew long and little room was left for the items.
- Only one label at a time could be used as a filter. To find, for example, the calls of a category with two specific tags, you had to scroll by hand.

## Decision
- **Three columns**, as in variant B shown to the user:
  - **on the left the labels**, in two boxes that fold: *Categories* and *Tags*. Tags are sorted by use and have a search field: Return adds the first match. Chosen tags appear as blue tiles with the ✕ to remove them, and *Reset* removes everything. With a right click a tag is pinned at the top, in *Pinned*;
  - **in the middle the list** of items, with a header saying what is being filtered;
  - **on the right the detail** of the chosen item.
- **Combined filter:** a category and every chosen tag apply together, as AND (`Archive.summaries(categoryID:tagIDs:)`). With nothing chosen the list shows the items that have at least one category or tag.
- **Widths:** two handles between the columns can be dragged, and a double click brings them back to the base size. The sizes are kept across launches (`labels.width.labels`, `labels.width.list`), like the boxes being open or folded (`labels.categoriesOpen`, `labels.tagsOpen`). The labels column goes from 200 to 420 points, the list is at least 240 points and the detail at least 360.
- In the wide view *Categories and tags* does not show the right panel of the other places: the detail is already the third column.

## Consequences
- The preferences of this view are neither read nor written by the demo tour, so the guide's screenshots are always the same.
- No change to the data schema: the filter uses the existing `item_tag` and `category_id`.
