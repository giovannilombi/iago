# ADR-0001 — Native Swift/SwiftUI app, no fork

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 1, 4.1, 17.1

## Context
IAGO must integrate deeply with macOS: Core Audio (process tap, devices), a menu bar with distinct left/right clicks, Keychain, system permissions. Similar open source projects exist (Meetily, Hyprnote), based on Tauri/Electron or with architectures different from our privacy and data model requirements.

## Decision
Native app in Swift 6 (strict concurrency) with SwiftUI for the views and AppKit where needed (`NSStatusItem`, utility windows). No webview for the main UI. No fork of existing apps: Meetily, Hyprnote and the AudioCap sample are references only, respecting their licenses.

## Consequences
- Direct access to system APIs without bridges; small footprint.
- All the code is ours: more initial work, no inherited debt.
- macOS only. Web/mobile clients (phase 4) will be a separate project.
