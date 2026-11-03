# ADR-0065 — Clean repository, 1.0.0-beta and no real data in commits

- Status: accepted
- Date: 2026-10-24
- References: ADR-0060 (publishing the repository, option B), ADR-0056 (updates from GitHub Releases), ADR-0059 (distribution without notarization); user's directions of 2026-10-24

## Context
- The user wants to show IAGO to a technical colleague and then decide whether to distribute it.
- ADR-0060 foresees a new repository with a single commit, to be done when the user is ready. Now it is needed before distribution, for the review.
- The user asks for three permanent rules:
  - Claude never appears as a co-author;
  - no commit ever carries recording data or other real data: the app must always stay clean;
  - the version is **1.0.0-beta** until there is a first distributable version.

## Decision
- **Repository** (carrying out ADR-0060 in two steps):
  - the development repository becomes `giovannilombi/iago-archivio`, private, with all the history and PRs;
  - `giovannilombi/iago` is created, **private**, with a single commit "IAGO 1.0.0-beta". Collaborators (the colleague for the review) are invited there;
  - it becomes public, with the first release, only when the user decides to distribute. Until then automatic updates do not work, because they download from a public repository.
- **Version:** `1.0.0-beta` in `project.yml`. The following betas are `1.0.0-beta.2`, `.3`…; `scripts/release.sh` accepts them. 1.0.0 will be the first distributable version.
- **No AI attribution:** no Claude `Co-Authored-By` and no "Generated with Claude Code" in commits and PRs. A `commit-msg` hook blocks commits that contain them.
- **Never real data in commits:** a `pre-commit` hook (`scripts/check-private-data.sh`) blocks:
  - audio, encrypted archives, databases, models, Teams transcripts and emails (`.vtt`, `.eml`), the test recording folders, the local spec and handover;
  - the words listed in `Config/private-terms.local`: real names of people, clients and domains. The file is ignored by git, so the list itself never leaves the Mac.
- `scripts/bootstrap.sh` installs the hooks (`core.hooksPath scripts/git-hooks`).
- The commit author uses the anonymous GitHub email address (`…@users.noreply.github.com`), not the personal one.

## Consequences
- The colleague sees code, ADRs, guide and documents without the history that contained real data.
- The hooks are local: whoever clones must run `scripts/bootstrap.sh`. CI does not know the real names and cannot do the same check.
- The rules of ADR-0060 remain valid: made-up names in examples, screenshots only from the demo archive.

## Change of 2026-10-24 (authors)
- **1.0.0-beta:** sole author Giovanni Lombi.
- **From later versions** (made precise by ADR-0089: from the first version with the work on sharing, phase 4): the rights belong to **Giovanni Lombi and Gianluca Sestito**. Every commit names both: whoever makes it is the author, the other appears as `Co-Authored-By`. The `commit-msg` hook adds the missing lines on its own by reading `Config/team.txt`; a new author is added there.
- Claude never appears, neither as author nor as co-author.
- The new archive example and the ban on content in the app are in ADR-0066.

## Change of 2026-10-25 (email addresses)
- **Context:** an author's personal address had ended up in `Config/team.txt` and, through the hook, in the `Co-Authored-By` lines; another's was the author of merges made from the GitHub website. The history was rewritten and the repository recreated, because closed PRs keep the old commits.
- **No personal email address in the repository**, neither in files nor in commits (author, committer, message). Authors use only the anonymous GitHub address (`<id>+<utente>@users.noreply.github.com`), also in `Config/team.txt`; examples use made-up domains.
- **Checks, on three levels:**
  - `pre-commit` (`scripts/check-private-data.sh`): blocks an author or committer that does not use the anonymous address and, in files, the addresses of personal mail services (Gmail, iCloud, Outlook, Libero…); real work domains go in `Config/private-terms.local`;
  - `commit-msg`: blocks a message with an email address other than the anonymous GitHub one;
  - `pre-push` (`scripts/check-commit-emails.sh`): rechecks every commit about to go out, including those made with `--no-verify`, from a merge or from another program;
  - on GitHub, the `privacy.yml` workflow (Ubuntu, a few seconds) runs the same checks on every PR and every push to `main`, because local hooks can be skipped and a new clone does not have them until it runs `scripts/bootstrap.sh`.
- **Each author's GitHub account:** in Settings › Emails, "Keep my email addresses private" (merges made from the website use the anonymous address) and "Block command line pushes that expose my email".

## Change of 2026-10-30 (rights and version numbers)
- The rights belong to **Giovanni Lombi until the work on sharing starts** (phase 4, ADR-0057) and to **Giovanni Lombi and Gianluca Sestito from the first version with that work**, the first done together. This replaces the 1.3.x-beta and 1.4.0-beta thresholds of the change of 2026-10-29.
- Versions stay on 1.2.x-beta until the repository is public; then the version is **1.3.0**, without `-beta`, unless the user says otherwise.
- Settings › About shows Giovanni Lombi until that version.

## Change of 2026-10-29 (rights)
- The rights belong to **Giovanni Lombi up to 1.3.x-beta** and to **Giovanni Lombi and Gianluca Sestito from 1.4.0-beta**. This replaces the "from the versions after 1.0.0-beta" of the change of 2026-10-24.
- Commits name both from the first version with the work on sharing (`Co-Authored-By` added by the `commit-msg` hook, ADR-0089).
- Settings › About shows Giovanni Lombi up to 1.3.x-beta; the site names both and links to the README's credits.
