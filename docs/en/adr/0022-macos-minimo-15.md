# ADR-0022 — Minimum macOS 15

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 4.1, 17.A

## Context
Process taps are available from macOS 14.2, and the process object properties used to identify the microphone in use from macOS 14. The spec proposes 15 as the default and 14.4 as an alternative. Development happens on macOS 27; potential colleague users are on recent versions.

## Decision
Deployment target **macOS 15.0**, Apple Silicon only.

## Consequences
- More mature Core Audio and SwiftUI APIs, fewer `if #available` branches.
- Macs stuck on macOS 14 are excluded: acceptable for personal and team use.
- APIs introduced after 15 (e.g., SpeechAnalyzer) require availability checks.
