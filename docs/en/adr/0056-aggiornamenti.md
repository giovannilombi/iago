# ADR-0056 — App updates

- Status: accepted (A, decided by the user on 2026-10-21: the repository becomes public)
- Date: 2026-10-21
- References: CLAUDE.md › Network and privacy; "pre-distribution" memory; user request 2026-10-15 and 2026-10-21 (distribute soon, to colleagues too)

## Context
- IAGO must check whether there is a new version, ask whether to install it and, for major versions, be able to make it mandatory.
- The GitHub repository is private: a user without an account can download neither the releases nor an updates file.
- There is no paid Apple account, so the app is not notarized (see `docs/installazione.md`).
- The company has a shared OneDrive, which the user also wants to use for sync (phase 4).

## Options
### A. Sparkle (MIT) with a public repository just for releases
- A public `iago-releases` repository contains `appcast.xml` and the `.zip` files. IAGO checks once a day, downloads, verifies the EdDSA signature and installs.
- Sparkle handles critical updates (`criticalUpdate`) and the minimum version.
- **Cons:**
  - it is a **new network exception** in CLAUDE.md;
  - the app becomes downloadable by anyone who has the link;
  - colleagues do not need it, because they already have OneDrive.

### B. Updates from the company OneDrive folder (recommended)
- **Publishing:** the release script copies into a shared OneDrive folder, for example `IAGO/Aggiornamenti`:
  - `IAGO-x.y.z.zip`;
  - `aggiornamento.json` with version, minimum version, notes and SHA-256.
- **Receiving:** IAGO reads the folder, which OneDrive syncs to the Mac. When there is a newer version:
  - it offers **Update now / Later**;
  - below the **minimum version** the update is mandatory: IAGO asks for it at launch and does not start recordings until it is done. Recordings in progress are never interrupted.
- **Checks before installing:**
  - SHA-256 of the file;
  - the new app has the **same signature and the same Team ID** as the installed one. This way bundle and permissions do not change, and a tampered file is rejected.

  Then IAGO replaces the app in Applications and relaunches.
- **Pros:**
  - IAGO **makes no network connection**: the rule stays intact;
  - it works for the whole company with what is already there;
  - it is consistent with the OneDrive sync of phase 4.
- **Cons:** it does not work outside the company. If that is ever needed, A is added.

## Decision
**A, Sparkle 2.10.0 with the repository's releases**, which becomes public.
- **Where:**
  - feed `https://github.com/giovannilombi/iago/releases/latest/download/appcast.xml`;
  - the zip is attached to each release;
  - EdDSA signature with the key in the developer's Keychain (account `iago`). The public key is in Info.plist (`SUPublicEDKey`).
- **Check:** once a day (`SUScheduledCheckInterval`), can be turned off in Settings › General › Updates, with "Check now" also in the parrot menu. Every check and every installation goes into the access log (`update`).
- **Minor versions:** offered (install, later, skip).
- **Major versions:** mandatory. The script marks them `criticalUpdate`, Sparkle does not offer "skip", and IAGO does not start new recordings until they are installed. Those in progress are never interrupted.
- **Release:** `scripts/release.sh x.y.z --notes "…" --github`, which:
  - sets version and build;
  - builds the signed Release;
  - creates the zip and signs it with `sign_update`;
  - writes `appcast.xml`;
  - creates the GitHub release with zip and appcast.
- **Network exception in CLAUDE.md:** checking for and downloading signed updates from GitHub Releases.
- **B (OneDrive folder)** remains an idea for company installations without access to GitHub; it is not implemented.

## Consequences
- Before opening the repository it must be checked that it contains no personal data or recordings: the spec, HANDOVER.md and `Test-recordings/` are already excluded from git.
- If the EdDSA key is lost, users no longer accept updates: it must be saved (`generate_keys --account iago -x <file>`) in a safe place.

## Change of 2026-10-30 (1.2.8-beta)
User's decision: major versions stay mandatory, with **2 days of margin**.
- From when IAGO sees a mandatory update, the menu shows until when to install it and *Update now…*.
- After the 2 days IAGO starts no new recordings, transcriptions, summaries or suggestions, not even automatic ones, and says how to update. The user only has to press *Update now*.
- The archive stays readable and exportable, and a recording in progress is never interrupted.
- A Mac that is always offline does not see the update and so is not blocked.
