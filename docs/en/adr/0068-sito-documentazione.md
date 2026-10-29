# ADR-0068 — Documentation site with VitePress on GitHub Pages

- Status: accepted (automatic publishing when the repository becomes public)
- Date: 2026-10-24
- References: ADR-0061 (built-in guide), ADR-0060 and ADR-0065 (private repository until distribution)

## Context
- Those who install IAGO, and those who evaluate it before installing it, need documentation readable outside the app: requirements, installation with "Open Anyway", permissions, usage, shortcuts, problems and logs.
- The user guide already exists inside the app (`App/Resources/Guide`) and is updated with every visible change: a second copy to keep aligned must not be created.

## Decision
- **VitePress 1.6.3** with root in `docs/`, `base: '/iago/'`, dark theme by default, local search, Italian interface.
- **A single source for the guide:** `scripts/docs-sync-guide.mjs` copies the chapters of `App/Resources/Guide` into `docs/guida/` (with screenshots, logo and icon) before each build; the copied files are ignored by git. The sidebar takes its titles from the chapters.
- **Site-only pages:** `docs/index.md` (presentation), `docs/installazione.md` (requirements, Gatekeeper, permissions, calendar, updates, uninstalling), `docs/scorciatoie.md`, `docs/problemi-e-log.md`.
- **Outside the site** (`srcExclude`): the team's internal documents, that is ADRs, designs, benchmarks, phases, status, tests and licenses. They stay on GitHub.
- **Publishing:** `.github/workflows/deploy.yml`, the official VitePress workflow, on every push to `main` that touches the documentation or the guide.
  - GitHub Free does not offer Pages for private repositories: as long as `giovannilombi/iago` is private the jobs are skipped and enabling Pages via the API returns "plan does not support".
  - When the repository becomes public: enable Pages with `gh api -X POST /repos/giovannilombi/iago/pages -f build_type=workflow` and run the workflow. The site will be at `https://giovannilombi.github.io/iago/`.
- **Commands:** `npm install`, then `npm run docs:dev` to work locally, `npm run docs:build` for the full check (fails on broken links).

## Consequences
- Node.js is needed by those who work on the site; the app and the Swift packages do not depend on it.
- The Actions minutes for the site run on Ubuntu, which GitHub Free counts once (not ten times like macOS).
- With every change to installation, permissions, shortcuts or logs, the corresponding site page is also updated.

## Change of 2026-10-24 (two levels and alignment)
- **Two levels**, with the **Usage | Technical** switch in the top bar:
  - **Usage:** the app's guide (copied from `App/Resources/Guide`, hence always identical to the internal one) plus installation, shortcuts, problems and logs. Each chapter has at the top the link to the corresponding technical page.
  - **Technical:** `docs/tecnica` (architecture, data, capture, transcription, import, intelligence, engine, Claude and MCP, privacy and network, distribution, development, quality), plus ADRs, status, tests, licenses, designs, benchmarks and phase history.
- **The guide inside the app stays usage-only:** no technical or build details; the style stays the current one.
- **Alignment with every commit:**
  - the functional part of the site *is* the app's guide: it cannot diverge;
  - the `commit-msg` hook blocks a commit that changes the code of the app or the packages without touching `App/Resources/Guide` or `docs/`, unless there is a `Docs: <motivo>` line;
  - on every PR that touches the documentation CI builds the site (broken links make the build fail); on every push to `main` the site is republished, when the repository is public.
- The project documents previously excluded (ADRs, status, tests, benchmarks, designs, phases, licenses) enter the Technical level; only `docs/testing` stays out.
- Mermaid diagrams with `vitepress-plugin-mermaid` 2.0.17 and `mermaid` 11.4.1.
