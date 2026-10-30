# IAGO — ClickUp (idea for later)

Idea of October 30, 2026, to pick up at a later time. No ADR yet: one will be needed before writing code, because today IAGO does not talk to ClickUp (ADR-0058).

## In one sentence
ClickUp remembers **what** changed in a ticket, IAGO **why**: the calls, the emails, the decisions. Linking them puts the ticket and its history next to the call where it was discussed.

## Already possible, without code
Claude, with the ClickUp connector and with IAGO (MCP), acts as the bridge: it creates tickets from confirmed tasks, compares tickets and decisions, comments on a ticket with the call's summary. To be tried on a test project; the ClickUp admin must allow the connector.

## To do later, in this order
1. **«ClickUp» ADR:** a new network call to the ClickUp API, with the personal token in the Keychain, only if the user turns it on, recorded in the access log. No webhooks (they would need an open port): IAGO checks every 15–30 minutes or by hand, and the check shows in Activity.
2. **«Send to ClickUp»:** a confirmed task or request becomes a ticket, with description, owner, due date and the sentence of the call it comes from. Mappings set once: client ↔ Space, project ↔ Folder or List, stream ↔ List, contacts ↔ members. After a call, task suggestions are confirmed and the user chooses whether to send them.
3. **Status coming back:** a ticket closed in ClickUp closes the task in IAGO, with the outcome «from ClickUp». The Inbox also shows the tickets assigned to the user, with their own icon.
4. **Log of followed lists:** only the chosen lists, read-only. Each ticket is an item of type «ticket» with description, fields and a timeline (creation, status, owner, due date, comments), with date and author.
5. **The ticket in the memory:** search and *Ask* across calls, emails and tickets together; suggested links between a call and the tickets it talks about; project overview and status summary with ClickUp's movements; cross suggestions («in the call you decided X, the ticket still says Y»), always to confirm.
6. **Before a call:** in the item card, the project's open tickets recently moved, overdue or with unanswered comments.
7. **ClickUp Docs** imported as IAGO documents, with the same search.

Left out: call time recorded as time spent on tickets.

## Boundaries
- No copy of the whole workspace and no two-way editing of tickets from IAGO: duplicates and conflicts would make IAGO a second ClickUp.
- From IAGO to ClickUp only explicit user actions: create, comment, close.

## Open questions
- How ClickUp is organized at work (one List per project or per client) and on which plan: API limits depend on the plan.
- If several colleagues use IAGO, who creates the ticket, so the same call does not produce two identical tickets.
- What matters most: calls becoming tickets (points 2–3) or tickets in the memory (points 4–5).
