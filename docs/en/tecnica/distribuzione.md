# Distribution and updates

## Without the App Store and without notarization (ADR-0059)
- The App Store requires the sandbox, which does not allow recording the audio of other apps.
- Notarization requires a paid Apple account: IAGO is signed with a free Apple ID (Apple Development) and whoever installs it uses **"Open Anyway"** the first time.
- Changing the signature or bundle ID would make macOS ask for all permissions again: it is not done.
- **DMG** (change of 2026-10-27, then ADR-0097): the first installation is a DMG; the zip remains for Sparkle.
  - **Contents:** IAGO, the link to *Applications* and `Leggimi - Read me.html`, the instructions in Italian and English with the "Open Anyway" steps and the Terminal command.
  - **Background:** it comes from `scripts/dmg/background.html`; `scripts/dmg/make-background.sh` renders it at 1x and 2x with a windowless Chrome and saves it in `background.tiff`, which is in the repository.
  - **Icon positions:** they are in `scripts/dmg/settings.py`, and must be kept in line with the background.
  - **Layout:** it is written by `dmgbuild` (BSD) without Finder, in `build/venv-dmg`.
  - **Script:** `scripts/dmg/make-dmg.sh <IAGO.app> <version>` builds the DMG; `release.sh` uses it, and on its own it rebuilds the DMG of an app already built. It stops if the instructions are empty or without the icon.
  - **Quarantine:** on another Mac the downloaded DMG is quarantined. The first step for whoever installs is `xattr -d com.apple.quarantine ~/Downloads/IAGO.dmg`: a DMG without quarantine does not pass it on to the app (ADR-0097, change).
- **Builds from source without updates:** `IAGO_DISTRIBUTION` (in `Config/Base.xcconfig`, `NO`) ends up in `Info.plist` as `IAGODistribution`; only `scripts/release.sh` builds with `YES`. `UpdateService` starts Sparkle only if it is `YES`: a copy compiled by a developer is updated with git and is not replaced by the published one, signed by someone else, which would make macOS ask for all permissions again.

## Updates with Sparkle (ADR-0056)
- **Sparkle 2.10** reads `https://github.com/giovannilombi/iago/releases/latest/download/appcast.xml`.
- Every release is an **EdDSA**-signed archive; the public key is in the app (`SUPublicEDKey`), the private one in the publisher's Keychain. IAGO installs only versions signed with the same key.
- **Kind of update** (ADR-0100), chosen by the user for every release with `--update`:
  - `optional`: no mark in the appcast;
  - `no-skip`: *critical*, so Sparkle offers no «Skip», plus `<iago:update>no-skip</iago:update>` (namespace `https://giovannilombi.github.io/iago/appcast`), so IAGO blocks nothing (`UpdateService.isMandatory`). It works from IAGO 1.3.3-beta: earlier versions treat it as mandatory;
  - `mandatory`: *critical* only.
- **Mandatory updates:** from when IAGO sees them there are 2 days of margin (`UpdateService.mandatoryDeadline`, date in `update.mandatoryFirstSeen`), with the deadline and *Update now…* in the menu; then IAGO starts no new recordings, transcriptions, summaries or suggestions (`AppModel.blockedByUpdate`). A recording in progress continues.
- It works because the repository is **public** (since November 7, 2026, first release 1.3.0-beta).

## Making a release
```sh
scripts/release.sh 1.0.0 --update optional --notes "Novità…" --github
scripts/release.sh 1.0.0 --update mandatory --notes "Novità…" --why "Perché è obbligatorio…" --github
```
1. Updates version and build in `project.yml` (`1.1.0`, or `1.1.1-beta` for a beta).
2. Builds the signed Release and verifies it with `codesign`.
3. Creates the zip, signs it for Sparkle and writes `appcast.xml`, with the kind of update and, in the notes, what changes and, if needed, why it is mandatory or important.
4. Creates the **DMG** with `dmgbuild`, putting the app icon in the instructions, and signs it with the same identity as the app. It also copies it as `IAGO.dmg`, the fixed name of the link at the top of the README.
5. With `--github` it publishes the release, marked as the latest, with the two DMGs, the zip, the appcast and the installation instructions in the notes.

**To verify before distributing** (test on a clean Mac or user account): "Open Anyway" only once, a Sparkle update without a new block and with permissions preserved, the lifetime of the free certificate and what happens when it expires.

After every release the README **Versions** table is updated.

## Repository and versions (ADR-0060, ADR-0065)
- `x.y.z-beta` until it is decided to distribute, then without `-beta`: the third number goes up with every PR that changes the app, the second with a large group of features. Every version has an annotated tag listing the features, which serves as a restore point (README › Going back to a previous version).
- Since November 7, 2026, with 1.3.0-beta, it stays in beta by the user's choice: `-beta` is dropped when they decide.
- `giovannilombi/iago` has been **public** since November 7, 2026 and was created with a single commit; the earlier history is in a separate private archive, which does not become public.
- The documentation site is on GitHub Pages (`deploy.yml`, ADR-0068).
