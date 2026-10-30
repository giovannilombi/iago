# Transcription

Transcription happens on the Mac. Two engines:

| Engine | Pros | Cons |
| --- | --- | --- |
| Whisper large-v3-turbo | more accurate on Italian | slower |
| Parakeet | about 4 times faster | less accurate on names |

## Who is speaking
Your track is **Me** (the name you gave at the start). The others' voices are separated by person ("Speaker 1", "Speaker 2"…). **Rename the speakers** in the item card, in the field next to *Speaker:*.
- The name is saved with **Return** or with the **⏎** button next to the field, and only then does it change in the transcript. Until you save it the field has a **red border**: the text stays there even if you move to another item, and **Esc** cancels it.
- **Similar names:** if a similar name already exists, IAGO asks whether it is the same person, for example «*Antonello* already exists. Is *Lello* the same person?». It recognizes names written differently (*Marco* and *Marco Rossi*), typos and the most common Italian nicknames (*Lello* and *Antonello*, *Peppe* and *Giuseppe*). If you say yes it uses the name it already knows and remembers it: next time it suggests it right away, also for nicknames it did not know.
- **Same name for two speakers:** sometimes the same voice gets split in two. If you give a speaker the name of another one in the same call, IAGO offers to **join** them: a single speaker remains, with all their sentences. Below the fields appears «Speaker 3 joined to Antonello» with **Separate**, which puts it back as it was.
- The names apply to exports and to what the engine writes from then on. A summary already written stays as it is: *Regenerate* rewrites it with the new names.
- **Before the summary:** if you ask for *Generate summary* or *Regenerate* and some speaker is still called «Speaker 1», IAGO asks whether you want to **name them first** (it takes you to the fields) or **go ahead as is**. The summary can always be regenerated later. Automatic summaries don't ask.

The local engine can also suggest the names.

## Several people in the room
People connected remotely are always told apart, even many of them from the same computer. For those in the room with you:
- **Meeting in person** (the Mac's audio is silent): IAGO separates the microphone's voices by itself. You stay «Me», the others become «Room 2», «Room 3»…
- **Call with someone next to you:** IAGO does not separate by itself, because the microphone also hears the call's echo. If it hears other voices besides yours, the card shows «On the microphone I heard other voices» with **Separate the voices**, which transcribes the call again.
- You can also decide it before: **Several people here in the room** from the menu while recording, or **Several people in the room** when you transcribe.
- **Present:** in the card, and in the panel after Stop, write who was there (a name and Return, or several names separated by commas). Next to each speaker still without a name a button lets you choose among those present. Those present also go into exports and *Share*.

## Recognizing voices
In **Settings › Voices** you can turn on *Recognize voices from one call to the next* (off by default). When you name a speaker, IAGO remembers their voice; in later calls it suggests the name ("Speaker 2 becomes Marco", *Recognized by voice*) and you confirm or dismiss it. It never assigns a name on its own.

- It applies to calls transcribed after you turn it on; for a call already transcribed, use **Transcribe again**.
- It needs at least about ten seconds of speech to recognize a voice.
- The room's voices count too, when they are separated. Yours («Me») does not.
- Voices stay only on the Mac and never go to Claude or into exports. In the same panel you see the known voices and can delete them one by one or all together.

## Glossary
In **Settings › Transcription › Glossary** write the names and acronyms that must be spelled right (companies, products, people), separated by commas. For each call IAGO adds the project, client, stream and contacts on its own. It works with Whisper and helps with many names, not all of them.

## After Stop
In Settings › Transcription choose what happens when a recording ends: **transcribe right away**, **ask**, or **transcribe and delete the audio** (the audio is deleted only after the transcript has been checked). You can also transcribe only when the Mac is plugged in.

## Correcting
You can transcribe again with the other engine, rename the speakers, and for documents and emails correct the text by hand (the automatic text can be restored). A Teams transcript (.vtt or .docx) can be attached to a recording.

## IAGO's and Teams' transcripts
A call can have **two transcripts side by side**: IAGO's and Teams'. *Attach Teams transcript…* **adds** it and does not replace IAGO's. In the same way, *Transcribe* on a call that has only Teams' adds IAGO's.
- In the Transcript section there are two tabs, **IAGO** and **Teams**, besides Markdown.
- In IAGO's transcript a minute starts the audio from there. In Teams' the minutes are **plain text**: Teams counts them from the start of its own transcription, not of the recording, and they do not match the audio.
- One of the two is the **main** one, with the ★ next to the tab's name: it is always the first, and usually IAGO's. Summaries, suggestions, exports and Claude use the main one. **Search** looks in both.
- To change it, open the other one's tab and press **Make main**. If the call already has a summary, IAGO asks first: the summary stays as it is until you regenerate it, and above it appears «Written from the IAGO transcript; the main one is now Teams» with *Regenerate*.
- *Delete this transcript…* removes one of the two, also later. The other stays. It cannot be undone, but the transcript can be made or attached again.
- Attaching another Teams transcript replaces the earlier Teams one, never IAGO's.
