# ADR-0003 — System track via global Core Audio process tap

- Status: accepted
- Date: 2026-10-11
- Spec references: sec. 3.2 (FR-11), 6.1, 17.3

## Context
The alternatives for capturing system audio are: virtual drivers (BlackHole, which require installation and changing the output), ScreenCaptureKit (screen recording permission, semantics tied to screens/apps) and Core Audio process taps (macOS 14.2+).

## Decision
Global process tap (global stereo `CATapDescription` that excludes the IAGO process) attached to a private aggregate device. The tap captures the mixdown before the physical device, so changing the output (speakers, headphones, AirPods) does not change the recorded content. If the default output changes, the aggregate is rebuilt and any gap is filled with aligned silence.

## Consequences
- No driver to install; "System audio recording" permission (`NSAudioCaptureUsageDescription`).
- There is no public API to read the permission state: it must be verified empirically (test during onboarding + silence detection, FR-16).
- Relatively recent and poorly documented API: a technical risk to eliminate in phase 0.
- App not sandboxed in v1 for simplicity.
