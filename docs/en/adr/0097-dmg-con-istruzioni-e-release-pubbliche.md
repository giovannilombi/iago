# ADR-0097 — DMG with background and instructions, releases on the public repository

- Status: accepted
- Date: 2026-11-07
- Changes: ADR-0059 (distribution without notarization), ADR-0056 (updates)
- References: ADR-0060 (public repository), ADR-0068 (documentation site); user request of 2026-11-07, design approved on a preview

## Context
- The DMG held only IAGO and the link to Applications. Whoever opened it did not know that on first launch macOS blocks the app, nor how to unblock it: the instructions were only in the README and on the site.
- Updates arrive with Sparkle from the releases of `giovannilombi/iago` (ADR-0056). While the repository is private, nobody without access receives anything. The address stays written in every installed copy, so it must be settled before the first distribution.
- The idea of an executable in the DMG that unblocks Gatekeeper does not work: a program that arrives with the same download is blocked just like IAGO.

## Decision
- **Releases on this repository, made public.**
  - The update address does not change: `releases/latest/download/appcast.xml`.
  - Every release also attaches `IAGO.dmg`, with a fixed name, so the link at the top of the README always downloads the latest version.
- **DMG with a background** (`scripts/dmg`):
  - the window is 660×400;
  - at the top it says «Trascina IAGO in Applicazioni / Drag IAGO to Applications»;
  - IAGO and Applications are joined by three red, yellow and green arrows, with the dark outline of the logo;
  - at the bottom, a yellow band invites people to read the instructions, in Italian and English;
  - the volume has IAGO's icon.
- **How the DMG is made:**
  - the background comes from `background.html`: `make-background.sh` renders it at 1x and 2x with a windowless Chrome and saves it in `background.tiff`, which is in the repository;
  - the layout is written by `dmgbuild` (BSD), without driving Finder, in a Python environment inside `build/` created by `scripts/release.sh`.
- **Instructions in the DMG:** the file `Leggimi - Read me.html`, a page with no network access and a language switch.
  - **Recommended way:** four illustrated steps (drag, open and press *Done*, *Privacy & Security › Open Anyway*, password).
  - **Quick way:** the command to copy into Terminal, `sudo xattr -dr com.apple.quarantine /Applications/IAGO.app`. The page says in plain words what it does and why it asks for the password, and advises using it only for apps you trust.
  - At the top, two buttons lead to the steps or to the quick way («Allergic to menus? One Terminal command and you're done»).
- **No unblocking executable in the DMG**, for the reason given above.
- **Change of 2026-11-08, unblocking the DMG:** on another Mac the downloaded DMG is quarantined and does not open.
  - The recommended first step, at the top of the README, in the installation guide and in the instructions, is `xattr -d com.apple.quarantine ~/Downloads/IAGO.dmg` in Terminal, without a password.
  - A DMG without quarantine does not pass it on to IAGO, so the app opens without «Open Anyway».
  - *Open Anyway* remains the way without Terminal.
- **The instructions never ship empty:** `scripts/dmg/make-dmg.sh` builds the DMG (also on its own, for an app already built) and stops if `Leggimi - Read me.html` is empty or without the icon. 1.3.0-beta and 1.3.1-beta had shipped with an empty page; the 1.3.1-beta DMGs were replaced.

## Consequences
- Whoever downloads IAGO finds everything in the DMG, even without having read the README.
- `scripts/release.sh` needs Python 3, the network the first time to install `dmgbuild`, and the Keychain with the signing keys.
- **To check on a clean Mac**, before the first distribution:
  - how the DMG looks in light and dark mode: in dark mode Finder may write the icon names in white;
  - «Open Anyway» and the Terminal command;
  - an update with Sparkle arriving without a new block.
- **Screenshots:** those in the instructions are drawn. They can be replaced with real macOS screenshots when the system's look changes.
