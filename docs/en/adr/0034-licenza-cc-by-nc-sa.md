# ADR-0034 — IAGO license: Creative Commons BY-NC-SA 4.0

- Status: accepted (user's choice, 2026-10-12)
- Date: 2026-10-12

## Context
The user wants a copyleft license that forbids commercial use and requires crediting the author.

## Decision
- IAGO is distributed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)** license, © 2026 Giovanni Lombi. Full text in `LICENSE`.
- In the app: Settings footer "Giovanni Lombi · CC BY-NC-SA 4.0".

## Consequences
- It is not an OSI-approved open source license (the NC clause rules that out), and Creative Commons advises against its licenses for software: it is nonetheless the only widespread one that combines copyleft, a ban on commercial use, and attribution, as requested.
- The dependencies (MIT, Apache-2.0) and the models (MIT, CC-BY-4.0) are compatible with non-commercial redistribution; their licenses remain valid and must be reported (`docs/licenses.md`, the app's "About" section).
