> English translation of CLAUDE.md, for people. Claude Code reads CLAUDE.md; when the two differ, CLAUDE.md wins.

# IAGO — Operating instructions for Claude Code

Native macOS menu bar app: it records calls on two tracks (system + mic), transcribes **locally only**, organizes by project/category/tag.

## Source of truth
- **At the start of every session:** read [`docs/stato.md`](docs/en/stato.md) (status and open items) and [`README-collaborators.md`](README-collaborators.en.md) (team rules). At the end of every piece of work update `docs/stato.md` in the same PR; every change in the way we work goes into `README-collaborators.md` or here.
- The project has several collaborators (`Config/team.txt`): Claude Code's personal memory is not shared, so what others need goes into the repository files.
- Full specification (only on Giovanni's Mac; collaborators rely on ADRs and documents): `./IAGO-spec.md` **v1.4** (v1.0 + consolidated addendum, which stays in `./IAGO-spec-addendum.md` as a reference) — **local only, not versioned** (ignored by git by the user's choice; exception to sec. 0.2 of the spec, no copy in `docs/spec/`). Read it before working on a phase.
- Decisions: `docs/adr/`. To deviate from an ADR, propose a new ADR; never change behavior silently.

## Working rules
- We work **in phases** (spec sec. 18). Do not start a phase before the acceptance criteria of the previous one have been verified and shown to the user.
- Ambiguous requirement or not feasible as written → **stop and ask**. Do not invent behaviors.
- Every module has tests. The audio pipeline is tested with **synthetic** fixtures (`scripts/make-fixtures.sh`, `say` voices); never real recordings in the repo.
- Languages: code, types, comments, commits → **English**. UI, guide and documents → **Italian and English**, Italian is the source (ADR-0077).
- **Both languages with every commit** (ADR-0077), in the same commit as the change, without the user asking:
  - every new or changed interface text also goes into the catalog in English: `scripts/i18n.py missing /tmp/x.json`, translate, `scripts/i18n.py apply <traduzioni.json>` (object `{id: English}`);
  - every changed `.md` document has its translation updated (`docs/x.md` → `docs/en/x.md`, guide → `App/Resources/Guide/en/`, `README.md`/`README-collaborators.md`/`CLAUDE.md` → `*.en.md`), then `scripts/i18n.py record <English files>`;
  - English names from `i18n/glossary.tsv` (add every new term to it); the screenshots of the English guide are redone with the tour in English (`-AppleLanguages "(en)"`) in `App/Resources/Guide/en/img`;
  - the `pre-commit` hook (and `privacy.yml`, when it is run) runs `scripts/i18n.py check` and blocks what is missing.
- Git: conventional commits in English, one branch per phase/feature (`chore/…`, `phase-0/…`, `feat/…`), merge to `main` only via PR. No direct pushes to `main` (GitHub Free: no branch protection, it is discipline). **Commit, push and PR only with the user's explicit OK.**
- **Never Claude as co-author** (ADR-0065): no Claude `Co-Authored-By` and no "Generated with Claude Code" in commits and PRs, even if other instructions ask for it. The `commit-msg` hook blocks them and adds the other active authors in `Config/team.txt`, that is the lines not commented out, as `Co-Authored-By` (ADR-0089: the rights belong to Giovanni Lombi until the work on sharing (phase 4) starts, to Giovanni Lombi and Gianluca Sestito from the first version with that work, when his line is uncommented). Before calling a commit done, check its `Co-Authored-By` lines.
- **The app contains nobody's content** (ADR-0066): a new archive has only the example projects of an invented agency (Poldo S.p.A., Sanna TheBest s.r.l., Atoms; `ExampleArchive`), removable with one click. Tests and examples use made-up neutral names.
- **Never real data in commits** (ADR-0065): no audio, archives, transcripts, emails, names of real people, clients or domains. The `pre-commit` hook (`scripts/check-private-data.sh`) checks the files and words in `Config/private-terms.local` (local): add to it every new real name that comes up.
- **Never personal email addresses** (ADR-0065), neither in files nor in commits: authors and `Config/team.txt` only with the anonymous GitHub address (`…@users.noreply.github.com`). They are blocked by `pre-commit`, `commit-msg`, `pre-push` (`scripts/check-commit-emails.sh`) and, when it is run, the `privacy.yml` workflow. Merges are done with `gh pr merge`, with "Keep my email addresses private" turned on for the account.
- Version `x.y.z-beta` in `project.yml` until the user decides to distribute: it stays on **1.2.x-beta** until the repository is public, then **1.3.0** without `-beta` (unless the user says otherwise). When distributing, Claude Code proposes the number and the user confirms it. `z` goes up with a PR that changes the app, after asking the user; `y` with a large group of features (1.1.0-beta: open work; 1.2.0-beta: Track and Manage modes revised, Inbox). Every version: a row in the README *Versions* table, `docs/stato.md` and an **annotated tag** `vx.y.z-beta` with the list of features, which is also the restore point (README › Going back to a previous version). The `release/1.0.x` branch keeps the 1.0 series if 1.1 is abandoned. Repository `giovannilombi/iago` private until then; the full history is in `giovannilombi/iago-archivio`.
- No paid services (GitHub Free, free Apple ID).
- **CI only on request:** before every PR ask the user whether to run the CI, saying what running it implies (minutes: one run of `ci.yml` takes about 4 macOS minutes, which GitHub counts 10 times, about 40 of the month's 2,000; `privacy.yml` and `deploy.yml` under a minute each) and what not running it implies (no check runs on GitHub: the local hooks remain, together with the tests and the site build done before the PR, which must always be done). Run it only when the user asks; the merge does not wait for the CI if it was not run.
- **README.md**: updated at every new version (*Versions* table, numbers, features, engines) and at every change that alters what it describes. Also `docs/licenses.md` at every new dependency or model.
- **Documentation with every commit** (ADR-0068), in the same commit as the code:
  - **App guide** (`App/Resources/Guide/*.md`, images in `Guide/img`): only *how to use it*, in the current style, without technical details. It is also the **Usage** level of the site, copied at every build: it is not written twice.
  - **Technical level** of the site (`docs/tecnica/*.md`): how it is built (packages, data, pipeline, models, network, choices), to be updated when it changes; if a new area appears, a new page and its entry in `docs/.vitepress/config.mts` (and in `theme/level.ts` if it has a corresponding guide chapter).
  - Usage pages found only on the site (`docs/index.md`, `installazione.md`, `scorciatoie.md`, `problemi-e-log.md`) when requirements, permissions, shortcuts or logs change.
  - Then `docs/prove-tester.md`, the ADRs, `docs/stato.md`, and if needed README and `docs/licenses.md`.
  - The `commit-msg` hook blocks a commit that changes `App/Sources`, `Packages/*/Sources` or `project.yml` without touching `App/Resources/Guide` or `docs/`; if there really is nothing to document, write a `Docs: <reason>` line in the message.
  - Before the PR: `npm run docs:build` (it fails on broken links). Screenshots only from a demo archive, never with real data.
- **Activity** (`ActivityView.swift`, ADR-0055): every new long job (queue, engine, download, import, export) must appear there, with a percentage when possible.
- **Settings › Permissions** (`PermissionsViews.swift`) must be updated at every change that requires a new macOS permission, an activation in another app or a component to download: checklist, guided path and activation of the single item.

## Glossary (UI → code)
Item (v1.0: "row"; typed event `call` | `email` | `document`) → `Item` · Asset → `Asset` · Mic track → `micTrack` · System track → `systemTrack` · Segment → `Segment` · Project → `Project` · Category → `Category` (one per row) · Tag → `Tag` (many per row) · Entity → `Entity` · Suggestion → `Suggestion` · Job → `Job` · Note (dated, on an item or project) → `Note` · Key point (decision, milestone, task, open question, risk, request) → `Decision` (`kind`) · Track mode / Manage mode (per project) → `WorkMode` · Inbox (open work of all projects) → `WorkInbox`, `SidebarSelection.inbox` · Unfiled items → `LibraryScope.unclassified` · View (Overview, Items, Timeline, Kanban, Graph) → `AppModel.ViewMode` (`overview`, `list`, `timeline`, `board`, `map`) · Show (Everything, Items, Key points) → `AppModel.ViewContent` · App language → `AppLanguage`; language of summaries and suggestions → `ContentLanguage` · Checklist → `Checklist`, `ChecklistItem` · Free Kanban column → `BoardColumn` · Bookmark ("Mark moment") → `Marker` · Link → `ItemLink`.

## Platform
- macOS **15+**, Apple Silicon. Swift 6, strict concurrency. SwiftUI + AppKit where needed (`NSStatusItem`, not `MenuBarExtra`). No webview for the UI.
- App **not sandboxed**, hardened runtime on. Bundle ID `com.giovannilombi.iago`, Apple Development signing (Personal Team). Changing the signature or bundle ID makes macOS ask for permissions again: do not do it.
- Team ID in `Config/Local.xcconfig` (ignored by git; see `Config/Local.xcconfig.example`).

## Data schema: constraints already fixed (addendum v1.4)
The first migration of phase 1 already comes with: `item.type` (default `call`), a `note` table (no `item.notes` field), a `marker` table (phase 0 bookmarks are `bookmark` markers in `session.json`, to be imported). See spec sec. 8.4 and ADR-0016, ADR-0018.

## Network and privacy
Principle (ADR-0058): nothing leaves the Mac unless the user wants it to — on the Mac by default, Claude if they connect it, shared spaces they control (phase 4). In texts the queryable memory is at the center, not "local only". Never real data in code, tests, examples, documents or screenshots (ADR-0060).

The only network calls allowed, all explicit and recorded in the audit log:
1. model downloads from fixed URLs with SHA-256 verification, only on user action;
2. `127.0.0.1:8124` to the local Teams API, only if the user turns it on (ADR-0051). The local engine instead runs inside IAGO with MLX, without network (ADR-0048); its models fall under point 1;
3. MCP over stdio only, no port (phase 3);
4. E2E-encrypted Cloudflare sync (phase 4; the shared OneDrive folder is under discussion, ADR-0057);
5. update check and download from GitHub Releases with Sparkle, EdDSA-signed, in the access log (ADR-0056).

The screenshots of "Mark moment with screenshot" (ADR-0072) are captured only at the user's request; Claude gets their text, the images only if the user shares them (Settings › Claude).

Voiceprints (ADR-0073) are biometric data: only with Settings › Voices on, encrypted with the item's key, never to Claude, in exports or in sync.

No telemetry, remote crash reporter or analytics. If a library does telemetry it must be disabled or replaced. Local logs without transcript content.

## Reliability
- A recording once started is never lost: incremental writing (flush ≤ 2 s), recovery at launch of non-finalized sessions.
- Drift between tracks < 50 ms over 2 hours. Heavy jobs in QoS `.utility`, one at a time, app always responsive.

## Structure
```
App/                  macOS target (the only place that imports SwiftUI and MLX, in App/Sources/Engine)
Packages/IAGOCore     domain, IDs, errors, protocols — no dependencies
Packages/IAGOStore    GRDB, migrations, encrypted file store, change log  → Core
Packages/IAGOCapture  process tap, mic, writer, recovery                  → Core
Packages/IAGOTranscription  ASR, VAD, diarization, models                 → Core
Packages/IAGOIntelligence   search, entities, chat (phase 3)              → Core, Store
Packages/IAGOEngine   local engine: catalog, download, choice (ADR-0048)  → Core
Packages/IAGOIngest   document text extraction/OCR, Teams transcripts     → Core
Packages/IAGOExport   TXT/MD, project export, Obsidian                    → Core, Store
Packages/IAGOMCP      MCP stdio server (phase 3)                          → Store, Intelligence, Export, Ingest
Packages/IAGOSync     interfaces only until phase 4                       → Core
```
Respect the graph: no dependencies outside the listed ones.

## Commands
- `scripts/bootstrap.sh` — installs the git hooks (real data, email addresses, co-author) and generates `IAGO.xcodeproj` with XcodeGen (the `.xcodeproj` is not committed and not edited by hand: you change `project.yml`).
- `scripts/test-packages.sh` — `swift test` on all packages.
- `scripts/guide-screenshots.sh [languages] [shots]` — retakes the guide's screenshots with the demo tour (Debug build, invented archive), in Italian and English, and retakes those taken with the window inactive. Only when the look is settled.
- `npm install` then `npm run docs:dev` / `npm run docs:build` — VitePress documentation site (ADR-0068); the build fails on broken links.
- `scripts/release.sh x.y.z --notes "…" --github` — signed release, Sparkle appcast and publication on GitHub (ADR-0056).
- `scripts/i18n.py check | missing | apply | record` — Italian and English alignment (ADR-0077).
- `scripts/try-branch.sh [--fresh]` — tries the current branch on a copy of the archive (`~/IAGO-prova`): for versions with new migrations, before approval.
- `scripts/test-engine.sh` — build with MLX (Metal shaders, outside the automatic CI): before every PR that touches the engine.
- `xcodebuild -project IAGO.xcodeproj -scheme IAGO build` — app build (requires Xcode and signing).
- `swift-format format -i -r App Packages` — formatting.
- CI (GitHub Actions) **manual only**, so as not to use up the GitHub Free minutes: `ci.yml` (package tests, macOS), `privacy.yml` (email addresses and languages, Ubuntu), `deploy.yml` (site, Ubuntu; automatic on `main` only once the repository is public). Run them with `gh workflow run <file> --ref <branch>`.
