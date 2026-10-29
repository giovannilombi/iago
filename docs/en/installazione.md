# Installing IAGO

It takes about ten minutes, including the guided setup.

## Requirements

| | Minimum | Recommended |
|---|---|---|
| Mac | Apple Silicon (M1 or later) | M2 or later |
| macOS | 15 Sequoia | the latest version |
| Memory (RAM) | 8 GB | 16 GB for summaries, 32 GB for the largest engine |
| Free space | 2 GB (app and transcription) | 5 to 10 GB with the local engine |

- **Transcription:** the models take about 1.6 GB and are downloaded during the guided setup.
- **Local engine** (optional, for summaries, suggestions and Ask): 2 to 7 GB depending on the model. Summaries require at least Qwen 3.5 9B.
- **Headphones:** not required, but without headphones the microphone also picks up the speakers.

## 1. Copy the app
1. Download `IAGO-x.y.z.dmg` from the [releases page](https://github.com/giovannilombi/iago/releases/latest) and open it.
2. Drag **IAGO** onto the **Applications** folder next to it, then open it from Applications.

Developers of IAGO use their own build compiled from source: they do not install the DMG on the same user account, because two copies of IAGO compete for permissions and archive.

## 2. "Open Anyway" (Gatekeeper, first time only)
IAGO is not distributed through the App Store and is not notarized by Apple, because notarization requires a paid account. The app is signed nonetheless. On first launch macOS blocks it with a message like "Apple could not verify "IAGO" is free of malware".

1. Click **Done**, not "Move to Trash".
2. Open **System Settings › Privacy & Security**, scroll down to **Security** and click **Open Anyway** next to IAGO.
3. Confirm with your password or Touch ID, then click **Open**.

After the first time IAGO opens normally, including after updates.

::: tip Why it is not on the App Store
App Store apps must run in a sandbox, which does not allow recording the audio of other apps. IAGO needs to hear the audio of Teams, Zoom and Meet to record your call.
:::

## 3. Guided setup
On first launch IAGO asks for:
- your name, which becomes "Me" in transcripts;
- the microphone, with a test;
- a test of the Mac's audio;
- notifications;
- the download of the transcription models.

Then a seven-page tour explains how to use it; you can find it again in **Settings › Help**. In the sidebar there is an empty example structure (**Test Client** with two projects): rename it to use it, or delete it.

## 4. macOS permissions
In **IAGO › Settings › Permissions** you find the list with the status of each item. **Turn on the missing ones** walks you through them one at a time.

| Permission | What it is for | Level |
|---|---|---|
| Microphone | your track | required |
| System audio recording | the track of the other participants | required |
| Notifications | transcription finished, summaries ready, suggestion to record | recommended |
| Open at login | being ready for every call | recommended |
| Calendar | meeting titles and the suggestion at start time | optional |
| Accessibility | following Teams mute | optional |
| Screen recording | *Mark moment with screenshot* (captures only when you ask) | optional |
| Local engine | summaries, suggestions and Ask IAGO | optional |

If a permission was denied, re-enable it in **System Settings › Privacy & Security**, under the corresponding item; then restart IAGO.

## 5. Work calendar (recommended)
To get meeting titles and the suggestion to record at start time:
1. **System Settings › Internet Accounts**: add your work account (for example **Microsoft Exchange**) and, if you use it, **Google**. Turn on **Calendars**.
2. In IAGO: **Settings › Audio › Meetings › Use the Mac Calendar**.

## 6. Updates
Once a day IAGO checks the releases page for a new version and offers it to you. Updates are signed. A new **major** version is mandatory: until you install it, IAGO does not start new recordings. You can also check manually, from the IAGO icon menu › **Check for Updates…**. This applies to IAGO installed from the DMG; a copy compiled from source is updated with git.

## Uninstalling
1. Quit IAGO (icon menu › **Quit**) and drag the app from the Finder to the Trash.
2. Your data stays in `~/Library/Application Support/IAGO`: delete that folder only if you really want to erase it. Beforehand you can make an encrypted backup from **Settings › Backup and transfer**.
