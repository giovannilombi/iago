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

With several people in the same room, turn on **Several people in the room** when you transcribe: IAGO also separates the voices on your track.

## Recognizing voices
In **Settings › Voices** you can turn on *Recognize voices from one call to the next* (off by default). When you name a speaker, IAGO remembers their voice; in later calls it suggests the name ("Speaker 2 becomes Marco", *Recognized by voice*) and you confirm or dismiss it. It never assigns a name on its own.

- It applies to calls transcribed after you turn it on; for a call already transcribed, use **Transcribe again**.
- It needs at least about ten seconds of speech to recognize a voice.
- Voices stay only on the Mac and never go to Claude or into exports. In the same panel you see the known voices and can delete them one by one or all together.

## Glossary
In **Settings › Transcription › Glossary** write the names and acronyms that must be spelled right (companies, products, people), separated by commas. For each call IAGO adds the project, client, stream and contacts on its own. It works with Whisper and helps with many names, not all of them.

## After Stop
In Settings › Transcription choose what happens when a recording ends: **transcribe right away**, **ask**, or **transcribe and delete the audio** (the audio is deleted only after the transcript has been checked). You can also transcribe only when the Mac is plugged in.

## Correcting
You can transcribe again with the other engine, rename the speakers, and for documents and emails correct the text by hand (the automatic text can be restored). A Teams transcript (.vtt or .docx) can be attached to a recording.
