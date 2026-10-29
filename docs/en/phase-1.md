# Phase 1 — MVP: status

Goal (spec 18): complete flow record → classify → transcribe (keeping or deleting the audio) → read → export → delete, with an encrypted archive and no unplanned network calls.

The work is split into blocks, each with its own branch and PR.

| Block | Content | Status |
|---|---|---|
| 1 | Archive and encryption (`IAGOStore`) | ✅ merged (PR #3) |
| 2 | From capture to the archive | ✅ merged (PR #4) |
| 3 | Transcription in the app | ✅ merged (PR #5) |
| 4 | Main window, detail, post-recording panel, trash | ✅ merged (PR #6) |
| 5 | Onboarding, settings, icon | ✅ code and user test |

## Block 1 — Archive and encryption

| Component | Where | Notes |
|---|---|---|
| Database | `IAGOStore/AppDatabase.swift`, `Migrations.swift` | GRDB 7.11.1, WAL, `secure_delete`, `v1` migration with the phase 1 tables (including `item.type`, `marker`, `note`, `trashed_at`) |
| Rows and sync | `Records/` | sync fields on every user table; every write goes through `SyncWriter` (version, `device_id`, `change_log` in the same transaction); tombstones for deletions |
| Keys | `KeyStore.swift` | master key in the Keychain (ADR-0028), per-item key in `item_key` |
| Encrypted files | `EncryptedFile.swift` | AES-GCM block format with 1 MB blocks (ADR-0027), SHA-256 of the plaintext content |
| Archive | `Archive.swift` | items, projects, default categories (FR-100), normalized tags with suggestions (FR-101), notes (FR-170…176), bookmarks, speakers (FR-41), encrypted assets, 30-day trash (ADR-0030), permanent deletion (crypto-shredding), settings, access log |

The real Keychain (`KeychainMasterKeyStore`) is verified in the signed app, in block 2: the tests use an in-memory key.

## Block 2 — From capture to the archive

| Component | Where | Notes |
|---|---|---|
| Paths | `IAGOCapture/StoragePaths.swift` | `iago.sqlite`, `Items/`, `Models/`, `tmp/sessions`, `tmp/finalized`, `tmp/scratch` (emptied at launch) |
| Archiving | `IAGOStore/RecordingArchiver.swift`, `App/Sources/ArchiveService.swift` | at Stop the finalizer writes into `tmp/finalized/`, then the tracks are encrypted into the archive as an `Unclassified · …` item (FR-17) with bookmarks in `marker` and pauses/devices in `capture_meta`; the plaintext is deleted only after the encrypted copy. Idempotent: at launch whatever is left in `tmp/finalized/` is picked up again |
| Recovery | `AppDelegate` | first the recovery of interrupted sessions, then the archiving of everything pending |
| Phase 0 | ADR-0029 | `Recordings/` imported and removed at first launch |
| Import (FR-30, FR-31) | `IAGOCapture/AudioFileConverter.swift`, "Import file…" menu, dragging onto the icon | conversion to m4a (AAC) in `tmp/scratch`, encrypted `audio_import` track, date = file creation, title = file name |
| Time Machine | `ArchiveService` | IAGO folder excluded (setting to include it in block 5) |
| Trash | `ArchiveService` | expired contents emptied at launch and every 24 hours |

The ring buffer planned for the audio callbacks (open question 4 of phase 0) isn't needed: the IOProcs are created with a dispatch queue (`AudioDeviceCreateIOProcIDWithBlock`), so the block doesn't run on Core Audio's real-time thread and allocation doesn't cause glitches.

## Block 3 — Transcription in the app

| Component | Where | Notes |
|---|---|---|
| Job queue | `IAGOStore/Jobs.swift` | `job` table, one job at a time at `.utility` priority, priority, progress, attempts, cancellation; interrupted jobs restart at relaunch; waits if starting isn't allowed ("only on power" option, spec 4.3) |
| Models | `IAGOTranscription/ModelManager.swift` | manifest with fixed source and SHA-256 (whisper turbo; FluidAudio VAD and diarization with a fingerprint of the whole folder); verification at every launch, download only on user action with access log, FluidAudio always offline and loaded from IAGO's `Models/FluidAudio` |
| Transcription | `App/Sources/TranscriptionService.swift` | tracks decrypted in `tmp/scratch` only during the job; encrypted `transcript.json`, then TXT and MD (`IAGOExport/TranscriptRenderer.swift`, sec. 11.1 with Addendum); speakers in `item_speaker`; "transcribe and delete the audio" rereads the JSON and verifies its SHA-256 before permanently deleting the audio (FR-54) |
| Diarization | `TranscriptionPipeline` | if FluidAudio rejects the audio (too short or with no speech) the transcript stays valid with a single speaker |
| Menu bar | `StatusItemController` | icon and percentage during transcription and download, "Cancel transcription", "Download transcription models…" when they are missing |
| Notifications | `Notifier` | if notifications are turned off, important messages (transcription completed, recording recovered) appear in a window |

The "Transcribe" actions arrive in the interface with the post-recording panel and the item detail (block 4); until then there are debug menu items.

## Block 4 — Main window, detail, panel, trash

| Component | Where | Notes |
|---|---|---|
| Main window | `App/Sources/UI/MainView.swift`, `WindowManager.swift` | sidebar (Unfiled, Recent, Projects, Categories, Tags, Trash), list with status (FR-73), detail; dragging files onto the window = import (FR-30); icon in the Dock only while a window is open |
| Item detail | `ItemDetailView.swift`, `MetadataEditor.swift` | title, date, project (also new), category, tags with suggestions (FR-101); player with track choice and clickable timestamps (FR-52); renamable speakers (FR-41); Markdown view; bookmarks; notes with date and type (FR-170…173); files with size, export, copy, delete (FR-53, FR-60); transcribe/transcribe again with confirmation (FR-55); "Several people in the room" (ADR-0031); delete with choice of trash/permanent and destination of the notes (FR-176, ADR-0030) |
| Post-recording panel | `PostRecordingView.swift` | after Stop (not for recovered sessions): metadata, bookmarks, the three actions (FR-20); if closed without a choice the item stays unfiled (FR-21) |
| Trash | `TrashView.swift` | restore, delete permanently, empty, days left |
| Refresh | `AppModel.swift`, `Archive.changes()` | the UI reloads at every database change; TXT and MD regenerated after changes to metadata, speakers and notes |
| Quit | `TranscriptionService.shutdown()` | the whisper model is released before quitting (otherwise whisper.cpp crashes on close) |

### Additions requested by the user (block 4)

| What | Where | Notes |
|---|---|---|
| Recording bar in the window | `ProjectsAndRecording.swift`, `WindowManager` | title bar accessory: status, duration, microphone, Mark moment, Pause, Discard, Stop |
| "Discard" and "Temporarily discarded" | ADR-0032 | permanent deletion after 1 hour |
| Projects | `ProjectNameMatcher`, `NewProjectSheet`, sidebar | duplicate check with explicit confirmation, "+ Add", pin to top, sorting by last use, accordion sections, right-click to move items |
| Timeline | `ProjectTimeline.swift` | brought forward from phase 2 (FR-80): main view of the project |
| "Several people in the room" | ADR-0031 | diarization of the mic track too |
| Generic import, Teams, attachments in notes | ADR-0033, `Packages/IAGOIngest` | OCR and documents brought forward from phase 2 |
| Text buttons | `ActionLink.swift` | actions in two columns in the panel and in the detail |

## Block 5 — Onboarding, settings, icon, installation

| Component | Where | Notes |
|---|---|---|
| Onboarding | `App/Sources/UI/OnboardingView.swift` | at first launch: welcome and privacy, "What you need" (nothing to install; check of macOS, Apple Silicon, space), name, microphone, system audio with a 5 s test (sentence spoken by `/usr/bin/say`, because the tap excludes IAGO), notifications, models |
| Settings | `App/Sources/UI/SettingsView.swift` | General (name, launch at login), Audio (fixed microphone), Transcription (Whisper or Parakeet, language, action after Stop FR-22, only on power), Categories, Privacy (Time Machine, access log), Space (archive and models), About; logo, author and license (ADR-0034) |
| Icons | `MenuBarIcon.swift`, `Assets.xcassets` | app icon from the logo; menu bar with the logo outline (template) and status dot |
| Installation | `scripts/install-app.sh` | signed Release build copied into `/Applications`: IAGO opens from Launchpad, Spotlight, the Dock or the Desktop |

Before delivery: no "Debug" reference visible to the user (development builds stay in `build/`, excluded from Spotlight).
