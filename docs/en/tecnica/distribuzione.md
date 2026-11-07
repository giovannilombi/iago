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
- **Builds from source without updates:** `IAGO_DISTRIBUTION` (in `Config/Base.xcconfig`, `NO`) ends up in `Info.plist` as `IAGODistribution`; only `scripts/release.sh` builds with `YES`. `UpdateService` starts Sparkle only if it is `YES`: a copy compiled by a developer is updated with git and is not replaced by the published one, signed by someone else, which would make macOS ask for all permissions again.

## Updates with Sparkle (ADR-0056)
- **Sparkle 2.10** reads `https://github.com/giovannilombi/iago/releases/latest/download/appcast.xml`.
- Every release is an **EdDSA**-signed archive; the public key is in the app (`SUPublicEDKey`), the private one in the publisher's Keychain. IAGO installs only versions signed with the same key.
- **Mandatory major versions:** the appcast marks them as *critical*. From when IAGO sees them there are 2 days of margin (`UpdateService.mandatoryDeadline`, date in `update.mandatoryFirstSeen`), with the deadline and *Update now…* in the menu; then IAGO starts no new recordings, transcriptions, summaries or suggestions (`AppModel.blockedByUpdate`). A recording in progress continues.
- It works only with the **public** repository: today it is private, so the check finds nothing.

## Making a release
```sh
scripts/release.sh 1.0.0 --notes "Novità…" --github
```
1. Updates version and build in `project.yml` (`1.1.0`, or `1.1.1-beta` for a beta).
2. Builds the signed Release and verifies it with `codesign`.
3. Creates the zip, signs it for Sparkle and writes `appcast.xml`.
4. Creates the **DMG** with `dmgbuild`, putting the app icon in the instructions, and signs it with the same identity as the app. It also copies it as `IAGO.dmg`, the fixed name of the link at the top of the README.
5. With `--github` it publishes the release, marked as the latest, with the two DMGs, the zip, the appcast and the installation instructions in the notes.

**To verify before distributing** (test on a clean Mac or user account): "Open Anyway" only once, a Sparkle update without a new block and with permissions preserved, the lifetime of the free certificate and what happens when it expires.

After every release the README **Versions** table is updated.

## Repository and versions (ADR-0060, ADR-0065)
- `x.y.z-beta` until it is decided to distribute, then without `-beta`: the third number goes up with every PR that changes the app, the second with a large group of features. Every version has an annotated tag listing the features, which serves as a restore point (README › Going back to a previous version).
- `giovannilombi/iago` is private and was created with a single commit; the earlier history is in a separate private archive.
- The documentation site goes online with the public repository (ADR-0068).
