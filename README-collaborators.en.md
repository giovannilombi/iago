# Collaborating on IAGO

This guide is for people who join the project without knowing its history. It explains what IAGO is, which documents we use and what they are for, the rules we follow, how the app is tested and how to work with Claude Code.

> **The rule of rules.** The way we work lives in these files, not in someone's head or in Claude Code's personal memory. Whoever changes a rule, a habit or a step of the workflow writes it here (or in `CLAUDE.md`, if it concerns Claude Code) in the same PR where they apply it. That way we all use the same ones.

## 1. What IAGO is, in one page
- A native macOS app (menu bar) that acts as a **queryable work memory**: it records and transcribes calls, collects emails, documents and notes, extracts decisions and tasks from them, and answers questions citing the sources.
- **The data belongs to the user.** It stays on the Mac by default; it leaves only if the user chooses so (Claude, or in the future a shared space they control). No telemetry.
- **The app contains no content.** Whoever installs it finds an empty archive with a single structure example (ADR-0066). Everything each of us records or imports stays theirs and never enters the repository.
- The [README](README.en.md) describes features, architecture, engines, measured numbers, installation and credits.

## 2. The documents and what they are for

| File | What it contains | When it is updated |
|---|---|---|
| [`README.md`](README.en.md) | What IAGO is, features, architecture, installation, versions, credits | At every version and every change that alters what it describes |
| `README-collaborators.md` (this one) | Rules, documents, workflow, tests | At every change in the way we work |
| [`CLAUDE.md`](CLAUDE.en.md) | Instructions for Claude Code: rules, glossary, structure, commands. It applies to all of us | At every new rule |
| [`docs/stato.md`](docs/en/stato.md) | **The restart point**: version, what is open, latest changes | At the end of every piece of work, in the same PR |
| [`docs/adr/`](docs/en/adr/README.md) | The decisions (ADRs), with context, alternatives and consequences; the index has the status of each one | For every new or changed decision |
| [`docs/prove-tester.md`](docs/en/prove-tester.md) | The manual tests, in order, designed for people who do not know the app | At every new or changed feature |
| [`App/Resources/Guide/`](App/Resources/Guide) | The guide inside the app (chapters in Markdown, screenshots in `img/`); it is also the site's guide | At every change visible to the user |
| `docs/index.md`, `docs/installazione.md`, `docs/scorciatoie.md`, `docs/problemi-e-log.md` | The usage pages found only on the documentation site (ADR-0068) | When requirements, installation, permissions, shortcuts or logs change |
| [`docs/tecnica/`](docs/en/tecnica) | The **Technical** level of the site: architecture, data, pipeline, models, network, development | In the same commit as every change to how the app is built |
| [`docs/licenses.md`](docs/en/licenses.md) | Dependencies and models, with versions and licenses | At every new dependency or model |
| [`docs/design/`](docs/en/design) | Designs of features still to be decided (e.g. sharing) | During the discussion |
| [`docs/benchmarks/`](docs/en/benchmarks) | Speed and quality measurements (numbers only, never call content) | At every new measurement |
| [`docs/phase-0.md`](docs/en/phase-0.md) … [`phase-3.md`](docs/en/phase-3.md) | What was done in each phase and how it was verified | Once the phase is closed, corrections only |
| [`docs/installazione.md`](docs/en/installazione.md) | Installing IAGO without notarization | If the procedure changes |
| [`Config/team.txt`](Config/team.txt) | The authors, used for commit co-authors | When someone joins |

**Local-only files, never in the repository:**
- `IAGO-spec.md` and `IAGO-spec-addendum.md`: the original specification, by Giovanni. The decisions that matter are recorded in the ADRs; for a doubt about the specification, ask him.
- `HANDOVER.md`: personal session notes.
- `Config/Local.xcconfig`: your own signing Team ID.
- `Config/private-terms.local`: the real names (people, clients, domains) each person wants to block in commits.
- `Test-recordings/`, `bench-out/`, `Models/`: test recordings, test results, downloaded models.

## 3. Rules

### Data
- **Never real data in the repository**: no audio, archives, transcripts, emails, names of real people, clients or domains. Examples and tests use made-up, neutral names (Test Client, Acme, Rossi…).
- Guide screenshots are taken only from the demo archive of the Debug build (ADR-0061), never from your own archive.
- An automatic check before every commit (`scripts/check-private-data.sh`) blocks forbidden files and words. Add to `Config/private-terms.local` the real names you use in your work: the file stays on your Mac.

### Authors and attribution
- The rights belong to **Giovanni Lombi** up to 1.3.x-beta, to **Giovanni Lombi and Gianluca Sestito** from 1.4.0-beta (ADR-0065). Every commit still names both: whoever makes the commit is its author; the other is added automatically as `Co-Authored-By`, by reading `Config/team.txt`.
- **Never an AI as author or co-author**, and no "Generated with…" line in commits and PRs. The commit check blocks them.

### Git and GitHub
- One branch per piece of work (`feat/…`, `fix/…`, `docs/…`, `chore/…`), from an up-to-date `main`.
- Changes enter `main` only through a **pull request**, with the tests and the site build done locally and the other person's OK. No direct pushes to `main`: GitHub Free does not prevent them, it is discipline.
- Conventional commits in English (`feat: …`, `fix: …`, `docs: …`).
- **Builds from source and DMG:** developers use their own build compiled from the code (updated with `git pull` and a new build; it does not look for automatic updates). The release DMG is for people who do not develop: to try it, use another user account or another Mac, because two copies of IAGO on the same account compete for permissions and archive.
- **Never a personal email address**, neither in files nor in commits (ADR-0065): sign with the anonymous GitHub address. In GitHub › Settings › Emails turn on "Keep my email addresses private" (so merges made from the website also use the anonymous address) and "Block command line pushes that expose my email". The git checks block commits and pushes with a personal address, and the Privacy workflow does the same on GitHub.
- GitHub's CI runs **only by hand**, when needed (`gh workflow run ci.yml --ref <branch>`, or from the Actions tab): GitHub Free minutes are few, and macOS ones count 10 times. Before every PR run `scripts/test-packages.sh` locally and, if the documentation changes, `npm run docs:build`; the local hooks do the other checks. With Claude Code: it asks whether to run it and what that implies.

### Languages
- Code, types, comments and commits: **English**.
- Interface, guide and documents: **Italian and English** (ADR-0077). Italian is the source; English is updated **in the same commit**:
  - app strings: `scripts/i18n.py missing /tmp/mancanti.json`, translate, `scripts/i18n.py apply traduzioni.json`;
  - documents: `docs/x.md` → `docs/en/x.md`, guide → `App/Resources/Guide/en/`, `README.md`, `README-collaborators.md` and `CLAUDE.md` → `*.en.md`; then `scripts/i18n.py record <English files>`;
  - the English names are in `i18n/glossary.tsv`.
- The `pre-commit` hook (and `privacy.yml`, when it is run) runs `scripts/i18n.py check`: if a translation is missing, the commit stops and says what is missing. With Claude Code, it does the translation during the work.
- Short, direct sentences, in both languages.

### Decisions (ADRs)
- A relevant decision is written as an ADR in `docs/adr/`, in the index format, and a row is added to the index.
- An accepted ADR is not rewritten: you add an "Amendment of …" section or a new ADR that replaces it.
- An ambiguous requirement is clarified before writing code.

### Code
- macOS 15+, Apple Silicon, Swift 6 with strict concurrency, SwiftUI with AppKit where needed. No webview.
- The package graph is fixed (see `CLAUDE.md` › Structure): no dependencies outside the listed ones.
- Every module has its own tests. The audio pipeline is tested with synthetic fixtures (`scripts/make-fixtures.sh`, `say` voices).
- **Network:** only the calls listed in `CLAUDE.md` › Network and privacy, all explicit and logged. No telemetry.
- Every long job appears in Activity; every new permission in Settings › Permissions.

### Documentation with every commit
Documentation is updated **in the same commit** as the code, not afterwards:
- **App guide** (`App/Resources/Guide`): only how to use it, in the current style, without technical details. It is also the Usage level of the site, so the two cannot diverge.
- **Technical level of the site** (`docs/tecnica`): how it is built, when that changes.
- **ADRs** for decisions, `docs/prove-tester.md` for tests, `docs/stato.md` for status.

The commit check blocks a commit that touches the code of the app or the packages without touching the guide or `docs/`. If there really is nothing to document (for example an internal refactoring), add a `Docs: <reason>` line to the message.

## 4. Setting up the Mac
1. Xcode with Swift 6, then `brew install xcodegen swift-format`.
2. `cp Config/Local.xcconfig.example Config/Local.xcconfig` and enter your own Team ID (a free Apple ID is enough).
3. `cp Config/private-terms.local.example Config/private-terms.local` and write in it the real names to block.
4. `git config user.name` and `git config user.email` with your **anonymous GitHub** address (`<id>+<user>@users.noreply.github.com`, in GitHub › Settings › Emails), the same one written in `Config/team.txt`. Never a personal address in the repository: the commit check blocks it.
5. `scripts/bootstrap.sh`: installs the git checks and generates `IAGO.xcodeproj` (the Xcode project is not committed: you change `project.yml`).
6. `scripts/test-packages.sh` for the tests, `scripts/install-app.sh` to install your own build in `/Applications`.
7. The documentation site needs Node.js (`brew install node`): `npm install`, then `npm run docs:dev` (preview with automatic reload at `http://localhost:5173/iago/`) or `npm run docs:build`.

Useful commands, with explanations, in README › Development and in `CLAUDE.md` › Commands.

## 5. ADR status
The full index with the status is in [`docs/adr/README.md`](docs/en/adr/README.md). Today:
- **Accepted and done:** from 0001 to 0077, except those below. The 0068 site is ready but will go online only with the public repository.
- **To be decided:**
  - **0057**, shared projects through a cloud folder: it is the core of phase 4. When accepted, it supersedes the 0012 backend (sync on Cloudflare).
  - **0067**, MiniCPM instead of Qwen 3.5 4B or in addition to it: the tests described in the ADR are needed.
- **Accepted, to be completed:** **0060**, publication of the repository. The clean repository already exists (0065); what is missing is making it public with the first release, when we decide to distribute.
- **No longer valid:** **0053** withdrawn (macOS echo cancellation took the microphone away from Teams), **0064** rejected (echo cleanup after recording made the voice worse).

What remains to be done, in order, is in [`docs/stato.md`](docs/en/stato.md).

## 6. Testing
- The manual tests are in [`docs/prove-tester.md`](docs/en/prove-tester.md), ordered and written for people who do not know the app.
- **Each tester has an issue on GitHub**, "Prove 1.2.3-beta — Nome Cognome", with all the tests as checkboxes. Check the box when the test works; for a problem write a comment with the test number (e.g. "3h.4"), what you did and what you saw. All collaborators read the issues and comments.
- A new round of tests (new beta, new tester) is opened with `scripts/new-test-round.sh "Nome Cognome" 1.2.3-beta`: the issue takes the tests from the current version of `docs/prove-tester.md`.
- A defect found becomes a separate issue, linked to the test; the fix comes with a PR that closes it.
- Tests do not need real data. Whoever tests with their own calls keeps that content to themselves: comments describe the behavior, not the content.

## 7. Working with Claude Code
- Development so far has been done with Claude Code. `CLAUDE.md` contains the instructions Claude reads at the start of every session: they apply to anyone who uses it on this repository.
- **Restarting with a clean session:** ask Claude to read `CLAUDE.md`, [`docs/stato.md`](docs/en/stato.md) and this guide, then the ADRs of the area you are working on.
- Claude Code's personal memory and local notes are not shared: everything others need goes into these files.
- Claude proposes, people decide: commits, pushes, PRs and merges only with the OK of whoever is working; for choices that change the product, an ADR is written or updated.
- At the end of every piece of work: update `docs/stato.md`, and if something changed in the way we work, this guide or `CLAUDE.md`.

## 8. The documentation site
- It is built with VitePress (ADR-0068) and will be at `https://giovannilombi.github.io/iago/en/`. GitHub Free does not publish sites of private repositories, so it will go online when the repository becomes public; until then you view it locally with `npm run docs:dev`.
- **Two levels** with the **Usage | Technical** switch at the top:
  - **Usage:** the guide, copied from the app chapters (`App/Resources/Guide`): it is edited there, never in the site. Plus installation, shortcuts, problems and logs.
  - **Technical:** `docs/tecnica` plus ADRs, status, tests, licenses, designs, benchmarks and phases.
- Every guide chapter has the link to the corresponding technical page (`docs/.vitepress/theme/level.ts`).
- The site is built locally before the PR (`npm run docs:build`); once the repository is public, every push to `main` will republish it by itself.

## 9. Making a release
- The version is in `project.yml`, in the form `x.y.z-beta`. The third number goes up with a PR that changes the app (ask Giovanni), the second with a large group of features. At distribution, `-beta` is removed.
- Every version has an **annotated tag** (`git tag -a v1.0.1-beta -m "…funzioni…"`) that acts as a restore point for code, guide and documentation; see README › *Going back to a previous version*. The `release/1.0.x` branch keeps the 1.0 series.
- `scripts/release.sh <version> --notes "…" --github` builds, signs the archive for Sparkle (the key is in Giovanni's Keychain) and publishes the release. It works only with the public repository, that is when we decide to distribute.
- At every release the README Versions table is updated.
