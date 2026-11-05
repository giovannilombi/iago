# Development

The complete team rules are in [`README-collaborators.md`](https://github.com/giovannilombi/iago/blob/main/README-collaborators.md) and the instructions for Claude Code in [`CLAUDE.md`](https://github.com/giovannilombi/iago/blob/main/CLAUDE.md). Here is the technical summary.

## Setting up the Mac
1. Xcode with Swift 6, `brew install xcodegen swift-format node`.
2. `Config/Local.xcconfig` from its `.example`, with your own Team ID.
3. `Config/private-terms.local` from its `.example`, with the real names to block in commits.
4. `git config user.email` with the anonymous GitHub address (`<id>+<utente>@users.noreply.github.com`), the same as in `Config/team.txt`; in GitHub › Settings › Emails turn on "Keep my email addresses private" and "Block command line pushes that expose my email".
5. `scripts/bootstrap.sh`: installs the git checks and generates `IAGO.xcodeproj`.

## Commands
| Command | What it is for |
|---|---|
| `scripts/bootstrap.sh` | git hooks + Xcode project from `project.yml` |
| `scripts/test-packages.sh` | `swift test` on all packages |
| `scripts/pre-pr.sh [--all]` | the checks before every PR, for everyone: real data, languages, tests, app build, engine and site; it prints the summary to paste in the PR (template `.github/pull_request_template.md`) |
| `scripts/test-engine.sh` | app build with MLX and Metal shaders (before PRs on the engine) |
| `scripts/install-app.sh` | signed Release installed in `/Applications` |
| `scripts/try-branch.sh [--fresh]` | tries the current branch on a **copy** of the archive (`~/IAGO-prova`, Debug option `-IAGOTrialRoot`): the real archive is not touched |
| `scripts/check-network-apis.sh` | no network APIs beyond the allowed ones |
| `scripts/check-private-data.sh --all` | no real data in the files |
| `scripts/check-commit-emails.sh main..HEAD` | no personal email address in commits |
| `scripts/make-fixtures.sh` | synthetic audio fixtures with `say` voices |
| `scripts/new-test-round.sh "Nome" [versione]` | test issue for a tester |
| `scripts/release.sh x.y.z --github` | signed release and appcast |
| `npm run docs:dev` / `docs:build` | documentation site |
| `swift-format format -i -r App Packages` | formatting |

## Rules that matter
- **Branches and PRs:** one branch per piece of work, merge to `main` only through a PR, with the tests and the site build done locally and the other person's OK.
- **Languages:** code and commits in English, interface and documents in Italian.
- **Decisions:** every relevant choice is an [ADR](/en/adr/); an accepted ADR is not rewritten, it is amended with a dated section or superseded.
- **Data:** never real data in the repository (ADR-0065); the app contains no content (ADR-0066).
- **Email addresses:** never a personal one, neither in files nor in commits; commits are signed with the anonymous GitHub address (ADR-0065).
- **Authors:** until the work on sharing (phase 4) commits have only Giovanni Lombi as author; from that version they also name Gianluca Sestito, added by the hook once his line in `Config/team.txt` is no longer commented out (ADR-0089); never an AI.

## Documentation with every commit
Every commit that changes the app's behavior updates the documentation in the same commit:
- **App Guide** (`App/Resources/Guide`), only how to use it: it is also the **Usage** level of this site, copied at every build.
- **Technical level** of this site (`docs/tecnica`), if how it is built changes: packages, data, pipelines, models, network.
- **ADR** if a decision changes, `docs/prove-tester.md` for the tests, `docs/stato.md` for the status.

## Italian and English (ADR-0077)
Italian is the source; every changed text is also updated in English, in the same commit.
- **App strings:** the String Catalog (`App/Resources/Localizable.xcstrings`) is filled by Xcode's extraction (`SWIFT_EMIT_LOC_STRINGS`). `scripts/i18n.py missing mancanti.json` lists the strings without English; once translated into a `{id: english}` object, `scripts/i18n.py apply traduzioni.json` writes them into the catalog.
- **Documents:**
  - `docs/x.md` has its translation in `docs/en/x.md`, the guide in `App/Resources/Guide/en/` with English screenshots;
  - `README.md`, `README-collaborators.md` and `CLAUDE.md` have `*.en.md`;
  - after translating, `scripts/i18n.py record <english files>` records in `i18n/sources.json` the Italian version they come from.
- **Names:** `i18n/glossary.tsv` fixes the English names of interface elements and concepts.
- **Check:** `scripts/i18n.py check`, in the `pre-commit` hook and in `privacy.yml` (when it is run). It blocks if:
  - a translation is missing;
  - the Italian changed after the translation;
  - a catalog string has no English;
  - a string in the code is not yet in the catalog.
- **Site:** VitePress with Italian at the root and English under `/en/` (`locales` in `docs/.vitepress/config.mts`); `scripts/docs-sync-guide.mjs` copies both guides.

## Git checks
`scripts/bootstrap.sh` enables the hooks in `scripts/git-hooks`:
- `pre-commit`: no real data in files (audio, archives, models, names from `Config/private-terms.local`, addresses of personal mail services), author and committer with the anonymous GitHub address, Italian and English in sync (`scripts/i18n.py check`);
- `commit-msg`: no AI co-author, no email addresses in the message, team co-authors added automatically, documentation in the same commit;
- `pre-push`: checks again the author, committer and message of every commit about to be pushed, including those made by skipping the hooks.

The `commit-msg` hook also blocks a commit that touches the code of the app or of the packages without touching the documentation, unless the message contains a `Docs: <motivo>` line (for example `Docs: refactoring interno, nessun effetto visibile`).

## CI
All workflows run **only by hand** (`gh workflow run <file> --ref <branch>`), when needed: GitHub Free minutes are few, and in October 2026 they ran out. Before every PR the package tests and the site build run locally; the hooks do the other checks.
- `ci.yml`, on macOS: network API check and package tests, about 4 minutes, which GitHub counts 10 times.
- `deploy.yml`, on Ubuntu: builds the site; publishes it on GitHub Pages by itself on every push to `main` only once the repository is public (while private the job is skipped and uses no minutes).
- `engine.yml`: build with MLX.
- `privacy.yml`, on Ubuntu: no personal email address in commits (author, committer, message) or in files; Italian and English in sync. A few seconds; real names remain a local check, because their list does not leave the Mac.
- Tests that use Vision, PDFKit and the AppKit importers have a time limit, and each package stops after 10 minutes with its name.
- The three Vision OCR tests **do not run in CI**: on GitHub's macOS runners Vision hangs without an error. They run on the developer's Mac with `scripts/test-packages.sh` (they are skipped where the `CI` variable is set).
- Imported HTML is converted with IAGO's own converter, without WebKit, which used to hang off the main thread.

## Structure
```
App/                      macOS target (SwiftUI, AppKit, MLX in App/Sources/Engine)
App/Resources/Guide/      app guide (Markdown + screenshots), source of the site's Usage level
Packages/                 the ten Swift packages
docs/                     site (index, installazione, tecnica/), ADRs, status, tests, benchmarks, projects
scripts/                  bootstrap, tests, release, checks, git hooks
Config/                   xcconfig, team, examples of the local files
Design/                   logo and icons
```
