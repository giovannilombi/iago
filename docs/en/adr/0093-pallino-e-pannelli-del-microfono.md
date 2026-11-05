# ADR-0093 — Yellow dot and panels when the microphone is not recording

- Status: accepted
- Date: 2026-11-05
- References: FR-16 (silent track), ADR-0004 (microphone following the call app), ADR-0051 (IAGO's panels at the top right); user request of 2026-11-05

## Context
- The dot on IAGO's icon in the menu bar turned yellow when a track stayed silent for more than 30 seconds while the other had signal (FR-16).
- So someone listening in silence saw yellow after 30 seconds, and red came back as soon as they spoke. The user read it as "recording without the microphone", with a delay that made it misleading.
- An unplugged or stopped microphone, on the other hand, is a real problem: the user's voice does not end up in the transcript. It has to be said at once and clearly.

## Decision
- **Red**: recording with the microphone. **Yellow**: no audio is coming from the microphone, meaning no device or no buffer for more than 2 seconds (`SilenceAlarm.micAbsent`, `absentWindow`). Silence is not absence: a microphone that listens still sends buffers.
- The icon updates every second, as before: yellow arrives within about 2 seconds and goes away as soon as the microphone resumes.
- **Panel** at the top right, like the recording proposals (ADR-0051):
  - *The microphone is not recording*, as soon as the audio is missing, with *Choose the microphone* (Settings › Audio) and *Ignore*. If the user answers, it does not come back until the microphone resumes and then stops again;
  - *The microphone does not hear your voice*, once per recording, when the microphone has been silent for more than 30 seconds while the others talk. It says that, if you are only listening, all is well.
- The FR-16 warning stays as a line in IAGO's menu and in the recording bar, no longer as the yellow dot. The recording bar also shows *No audio from the microphone*.

## Consequences
- Yellow has a single meaning and arrives in time.
- The silent-track panel appears at most once per recording: someone listening for a long time is not disturbed over and over.
