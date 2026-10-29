# ADR-0059 — Distribution without notarization

- Status: accepted
- Date: 2026-10-21
- References: CLAUDE.md › Platform (Apple Development signing, Personal Team), › Rules (no paid services); ADR-0056; `docs/installazione.md`, guide › Installation

## Context
Notarizing an app requires the Apple Developer Program, which is paid. IAGO is signed with a free Apple ID (Personal Team), with hardened runtime and a fixed bundle ID.

## Decision
- **Distribution:** zip signed with the same identity, from GitHub Releases, without notarization.
- **First launch:** the guide, the README and `docs/installazione.md` explain **"Open Anyway"** (System Settings › Privacy & Security).
- **Updates:** they go through Sparkle (ADR-0056), which installs only zips signed with EdDSA by the developer's key.
- **Permissions:** signature and bundle ID never change, so macOS keeps the permissions (microphone, system audio, Accessibility, Calendar) from one version to the next.

## Consequences
- Those who install must take an extra step the first time.
- If a paid account comes one day, notarization is added to the release script, without changing the rest.

## Change of 2026-10-27 (DMG and builds from source)
- **The first installation is a DMG** (`IAGO-x.y.z.dmg`) with IAGO and the link to Applications, signed with the same identity as the app; the zip remains for Sparkle updates. The "Open Anyway" step remains, only once.
- **Copies built from source code do not look for updates** (`IAGODistribution` in `Info.plist`, `YES` only in `scripts/release.sh` builds): developers update with git. Otherwise Sparkle would replace their build with the published one, signed by someone else, and macOS would ask for all the permissions again.
- Developers who want to try the DMG install it on another user account or on another Mac: two copies of IAGO on the same account compete for permissions and archive.
- **To be verified before distribution:** "Open Anyway" only once on a clean Mac; update with Sparkle without a new block and with permissions preserved; duration of the free certificate and what happens when it expires.
