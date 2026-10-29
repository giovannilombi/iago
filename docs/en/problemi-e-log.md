# Troubleshooting and logs

The most frequent problems, with their solutions, are in [Common problems](/en/guida/problemi). Here you find how to understand what is happening and how to collect information to send to whoever is helping you.

## First of all
1. **Settings › Permissions:** every item must be green. A denied permission is re-enabled in **System Settings › Privacy & Security**, then restart IAGO.
2. **Activity** (in the sidebar): shows what IAGO is doing, with the percentage. Heavy jobs run one at a time and pause during recordings.
3. **Restart IAGO:** icon menu › **Quit**, then reopen it from Applications. An interrupted recording is recovered at launch.

## Frequent problems

| Symptom | What to do |
|---|---|
| "No system audio" in the test | Enable IAGO in **Privacy & Security › Screen & System Audio Recording** and restart it |
| Other people's voices on my track too | Use headphones; during transcription IAGO discards repeated sentences anyway |
| The suggestion to record does not appear | **Settings › Audio › Meetings**: check the status line and try *Show a sample suggestion* |
| The meeting title is missing or wrong | Connect your work calendar (see [Meetings and calendar](/en/guida/riunioni)) |
| Teams mute is not followed | Enable **Accessibility** for IAGO |
| The summary does not start | It needs the local engine, at least Qwen 3.5 9B, and a category with a summary template |
| Names misspelled in the transcript | Add them to the **glossary** (Settings › Transcription) and transcribe again |
| macOS says IAGO cannot be opened | See ["Open Anyway"](/en/installazione) |

## IAGO logs
IAGO writes its logs to the macOS logging system. **They do not contain the content** of your calls, transcripts or documents: only technical events (launch, permissions, errors, job durations).

### With the Console app
1. Open **Console** (Applications › Utilities).
2. Select your Mac on the left and click **Start streaming**.
3. In the search field type `subsystem:com.giovannilombi.iago`.
4. Reproduce the problem, then select the lines and copy them.

### From Terminal
The last two hours:

```sh
log show --last 2h --info --predicate 'subsystem == "com.giovannilombi.iago"'
```

Live, while you reproduce the problem:

```sh
log stream --info --predicate 'subsystem == "com.giovannilombi.iago"'
```

Only one area, for example transcription:

```sh
log show --last 2h --info --predicate 'subsystem == "com.giovannilombi.iago" AND category == "transcription"'
```

| Category | What it covers |
|---|---|
| `app` | launch, windows, permissions |
| `calls` | suggestions to record, meetings, calendar |
| `teams` | Teams mute and the Teams local API |
| `transcription` | job queue and transcription |
| `archive` | archive, encrypted files, trash |
| `import` | imports and watched folders |
| `engine` | local engine and models |
| `intelligence` | search, suggestions, Ask |
| `backup` | backup and restore |
| `update` | update checks |

### Access log
**Settings › Privacy › Access log** lists every network connection made by IAGO (model downloads, update checks, Teams local API) and every read or write made by Claude, if you connected it.

## Asking for help
When you report a problem, include:
- the version of IAGO (**Settings › General › Updates**) and of macOS;
- what you did, what you expected and what happened;
- the log lines from the time of the problem.

Do not attach recordings, transcripts or work documents: describe the behavior, not the content.
