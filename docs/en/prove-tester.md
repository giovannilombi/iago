# IAGO — Tester checklist

An ordered list of tests, meant for people who don't know IAGO. For each test mark ✅ (works), ❌ (doesn't work, describe what you see) or — (not done, explain why).

You need:
- a Mac with IAGO installed in `/Applications`;
- a Microsoft Teams account;
- ideally your work calendar synced in the Mac's Calendar app (System Settings › Internet Accounts).

The tests don't require real data: use test meetings and test files.

> This document is updated with every new feature.

## 0. Preparation: permissions
- [ ] 0.1 Open IAGO › Settings › **Permissions**. The checklist appears with the status of each item.
- [ ] 0.2 Press **"Turn on the missing ones"** and follow the steps one at a time. Each item you enable turns green on its own within a few seconds.
- [ ] 0.3 From the checklist, clicking an item still to do starts only that item.
- [ ] 0.4 At the end at least all the "Required" items are enabled.

## 1. Icon and notifications
- [ ] 1.1 In the Dock and in the Finder the IAGO icon is the parrot.
- [ ] 1.2 Settings › Audio › Meetings › **"Send a test notification"**: a notification arrives with the parrot icon, not a white square.
- [ ] 1.3 Clicking the IAGO icon in the menu bar opens the menu (with **Start recording**); right-click, or Control-click, starts the recording, pauses it and resumes it without opening the menu. A normal click during a recording doesn't pause it.

## 2. Recording suggestions (meetings)
- [ ] 2.1 Settings › Audio › Meetings › **"Show a sample suggestion"**: an IAGO panel with **Record** and **Ignore** appears at the top right.
- [ ] 2.2 The panel doesn't disappear when you hover over it with the mouse, and it stays until you press a button (5 minutes at most).
- [ ] 2.3 Turn off "Recording suggestions stay until you answer": the sample panel disappears on its own after 30 seconds.
- [ ] 2.4 Create a test meeting with a Teams link that starts in 2 minutes. At the start time **"«title» is about to start"** appears.
- [ ] 2.5 Create two overlapping meetings: two panels appear, one below the other.
- [ ] 2.6 Press **Record**: the recording starts (the IAGO icon in the menu bar shows the time).
- [ ] 2.7 Without a calendar event, with IAGO idle, join a Teams call: after about 5 seconds **"You're in a Teams call"** appears.
- [ ] 2.8 Leave the call while IAGO is recording: after about 30 seconds **"The call has ended"** appears with **Stop**.
- [ ] 2.9 The title of the recorded item is the title of the calendar meeting, or "Teams call of …" if there was no event.

- [ ] 2.10 With a Calendar meeting in progress for more than 15 minutes, start another Teams call: the panel asks **which meeting** it is (one button per meeting plus "Teams call of …"). The chosen title is the item's title.
- [ ] 2.11 With two meetings starting at the same time, join one: with Accessibility enabled (sec. 3) IAGO picks the right one on its own; without it, it asks which one.

## 3. Microphone muted in Teams
- [ ] 3.1 Settings › Audio › Meetings › enable **"Follow Teams mute with macOS Accessibility"** and grant the permission.
- [ ] 3.2 In a Teams meeting the status line says "Microphone button found" and switches between "muted" and "microphone on" when you press the button in Teams.
- [ ] 3.3 Record with a muted stretch in which you speak: in the transcript that stretch of your voice is missing.
- [ ] 3.4 (Only if enabled in your company) Teams local API: in Teams › Settings › Privacy "Third-party app API" appears; enable it, then in IAGO "Connect the Teams local API" and allow IAGO in a meeting.

## 3b. Microphone and call apps
- [ ] 3b.1 During an IAGO recording the Teams microphone works: the others hear you, including while muted and after unmuting.
- [ ] 3b.2 In Settings › Audio there is only the microphone choice (no option that touches the call app's microphone).

## 3c. Activity
- [ ] 3c.1 In the sidebar, below Import, there is **Activity**. When something is in progress it shows a number.
- [ ] 3c.2 During a recording, Activity shows duration, microphone and, when muted on Teams, "silence on your track". Pause and Stop work.
- [ ] 3c.3 Start the transcription of two items: the first is "In progress" with percentage and time left, the second "Queued". "Do this first" and "Cancel" work.
- [ ] 3c.4 At the end they appear in "Last 24 hours". A cancelled transcription can be redone with "Retry"; "Open" opens the item.
- [ ] 3c.5 Import a file, make a backup and export the audio: each one appears while it works and then among the recent ones.

## 3d. Summaries by category
- [ ] 3d.1 Settings › Categories: the main ones (1to1, Kickoff, Progress review, Workshop, Review/Demo, Client/Sales, Customer discovery, Internal, Other) each have a summary template. The Agile, Management, People and Operations families are off.
- [ ] 3d.2 Turn on "Daily standup" (Agile): in an item's detail the category is chosen from Agile › Daily standup.
- [ ] 3d.3 "Edit the template…": change a section and save; the category shows "(edited)". "Restore the original" goes back. Export and re-import the template (JSON).
- [ ] 3d.4 Open a transcribed call with no category: the **Summary** block says "not yet available", with the category choice and "Generate summary".
- [ ] 3d.5 Choose the category and press Generate: progress appears (also in Activity) and then the summary. Each minute opens the player at that point.
- [ ] 3d.6 Sections with no content say "Not mentioned". The figures in the summary are the ones said in the call.
- [ ] 3d.7 Change the category: "Regenerate with the «…» template" appears, but the summary doesn't change on its own. "Edit…" and then "Regenerate" asks for confirmation.
- [ ] 3d.8 Record a new call with the category already chosen: at the end of the transcription the summary arrives on its own, with a notification.
- [ ] 3d.9 Search for a word from the summary: it appears among the results as "Summary". The summary is also in the project export and in Obsidian.

## 3e. Sidebar, categories and tags
- [ ] 3e.1 The sidebar has three parts separated by thin lines: the views at the top (fixed), "Projects" (the only part that scrolls, separated from the views by a blank space), a bar at the bottom with "＋" and the trash with the number of items.
- [ ] 3e.2 Clients open and close with a click on the header, as in Teams (when closed they show the number of projects). ⌥-click opens only that client and closes the others. On hover "→" (open the client) and "+" (new project) appear.
- [ ] 3e.2a "Pinned" (red pin) also opens and closes with a click.
- [ ] 3e.2b "No client" (small gray square) is always the last entry and contains the projects with no client and, at the bottom, "Undefined". With more than 15 projects "Filter projects" appears.
- [ ] 3e.3 "Categories and tags" shows the categories with the number of items and the tags; clicking opens the list across all projects.
- [ ] 3e.4 Right-click a category or a tag › "Pin to «Pinned»": it appears at the top of the sidebar.
- [ ] 3e.5 In the search field type `#` or `category:`: the tags or categories to open appear.
- [ ] 3e.7 On a Mac without IAGO (or with a new archive): at first launch the sidebar shows **Test Client** with **Test Pj. 1** (streams *Pj1 - Stream 1* and *Pj1 - Stream 2*) and **Test Pj. 2**; in "Pinned" there are *Pj1 - Stream 1* and *Test Pj. 2*. Once the client is deleted, the example doesn't come back after a restart. It doesn't appear on an archive already in use.
- [ ] 3e.8 Right-click a stream › **Pin to top**: it appears in "Pinned" with the project name below; **Unpin from top** removes it.
- [ ] 3e.6 In an item's detail, clicking a tag opens all the items with that tag. Next to the category there is no icon: all the items of a category are opened from Categories and tags.

## 3f. Help, tour and glossary
- [ ] 3f.1 At the first launch after setup the welcome tour appears (7 pages: memory, recording with the IAGO icon, imports, decisions and moments, summaries, Ask, data under your control). "Don't show again" turns it off; you can see it again from Help › Getting started.
- [ ] 3f.2 "IAGO Help" opens from the menu bar menu and from the "?" in the window; every topic can be read and the "Open Settings" buttons work.
- [ ] 3f.2b The **? Guide** button at the top left, next to Settings, opens the full-page guide: chapters on the left, text and images, search, "← Previous / Next →".
- [ ] 3f.2c Settings › **Help**: "Open the guide", "See the welcome tour again" and "Show the tour at launch" work.
- [ ] 3f.3 Settings › Transcription › Glossary: write a difficult name said in a call (e.g. a company), transcribe again: the name is spelled correctly.

## 3g. Updates and minimum engine for summaries
- [ ] 3g.1 Settings › General › Updates shows the installed version; "Check now" and the menu item "Check for updates…" open the Sparkle check.
- [ ] 3g.2 With a minor release published: IAGO offers it (install, later, skip) and after the installation it reopens with the new version.
- [ ] 3g.3 With a major release published: IAGO doesn't start new recordings until it is installed ("Required update"); a recording in progress continues.
- [ ] 3g.4 With Qwen 3.5 4B active, the Summary block says that at least the 9B is needed and "Generate summary" leads to Settings › Engine. With the 9B or Gemma the summary is generated.
- [ ] 3g.5 On a 16 GB Mac, Settings › Engine recommends Qwen 3.5 9B.

## 3h. Playback bar
- [ ] 3h.1 Open a call with audio and press Play: below the top bar the playback bar appears with Client › Project › Stream › Item, the controls, the time and the track.
- [ ] 3h.2 Switch to Activity, to another project or to Key points: the audio continues and the bar stays. Pause, 15 s back and forward and the position work.
- [ ] 3h.3 Clicking the path reopens the item you're listening to.
- [ ] 3h.4 When paused the bar stays; the **X** stops the audio and closes the bar.
- [ ] 3h.5 Open another item with audio while listening: the audio isn't interrupted; Play in that item switches to its audio and the bar updates.
- [ ] 3h.6 Changing track (Mix, Microphone only, System only) playback continues from the same point.
- [ ] 3h.7 With a recording in progress the two bars are stacked (recording on top). Closing the window stops the audio.
- [ ] 3h.8 Clicking a minute in the transcript or the summary starts the audio from there and opens the bar.

## 4. Search by meaning
- [ ] 4.1 Settings › Engine › Search by meaning › **Download**. The download finishes.
- [ ] 4.2 Indexing appears in the menu bar and finishes.
- [ ] 4.3 Search for a sentence with words different from those used in a call (e.g. "how much the company contributes"): "by meaning" results appear.

## 5. Automatic suggestions
- [ ] 5.1 Open a transcribed call › **"Find suggestions"**: after about a minute the Suggestions section appears.
- [ ] 5.2 **Confirm**, **Edit…** and **Discard** work. A discarded suggestion doesn't come back with "Search again".
- [ ] 5.3 The "N suggestions" badge appears in the list and in the timeline; Key points › **To confirm** shows them.
- [ ] 5.4 A new item (recorded or imported) receives suggestions on its own, with a notification.

## 6. Ask IAGO
- [ ] 6.1 The **"Ask IAGO"** button at the bottom right opens the panel. ⌘K does the same.
- [ ] 6.2 The X on the button hides it, and "Ask IAGO" appears in the sidebar below Import.
- [ ] 6.3 The panel closes with the X and resizes by dragging the left edge (minimum 300 points). The central part shrinks and the text wraps.
- [ ] 6.4 A question about the project gives an answer with numbered sources, which open at the right item and minute.
- [ ] 6.5 "Temporary conversation": **Keep** and **Delete** work. Pin and the list of conversations work.
- [ ] 6.6 Add an item and reopen a conversation: **"New material added"** appears with "Ask again".
- [ ] 6.7 "Save as note" puts the answer in the project notes.
- [ ] 6.8 Open Ask from a stream: the **Context** strip shows Client › Project › Stream (with the client's small square) and the field says "Ask about \<stream\>". With long names the path wraps onto two lines; on hover you can read it all.
- [ ] 6.9 **Widen context ▾** lists project, client and All memory, each with its type below. Before asking, the choice only changes the context.
- [ ] 6.10 After a question, widen: a new conversation opens in the chosen context with the same question; the previous one stays in the list.
- [ ] 6.11 From a widened context the link becomes **Change context ▾** and offers "Back to" the starting section.
- [ ] 6.12 An answer with no cited sources shows "Widen context ▾" below. In All memory the link isn't there.
- [ ] 6.13 Changing section in the sidebar before asking, the context follows it.

## 7. Add to IAGO (Services)
- [ ] 7.1 Select some text in another app › right-click › Services › **Add to IAGO**: the text becomes a document and IAGO opens it.

## 8. Watched folders for emails
- [ ] 8.1 Settings › Email and people › **Add folder**.
- [ ] 8.2 An `.eml` file placed in the folder is imported within a minute, with a summary notification.
- [ ] 8.3 A meeting invitation ends up in "Discarded". The same email placed twice doesn't get in twice.
- [ ] 8.4 An exclusion rule and an assignment rule work.
- [ ] 8.5 "Move to the «Imported» subfolder" and "Import anyway" work.

## 9. Claude (Claude Desktop)
- [ ] 9.1 Settings › Claude: connect a project, enable "Can write" and restart Claude Desktop.
- [ ] 9.2 Ask Claude to add a note: first it shows the preview, then it writes only after your OK. In IAGO the note has the label "via Claude (MCP)".
- [ ] 9.3 Ask Claude to import a PDF you have in Downloads: it finds it on its own and imports it with its text.
- [ ] 9.4 Settings › Claude › Undo a change by Claude: the entry goes back to how it was.

## 10. Multiple supersessions (key points)
- [ ] 10.1 In a project create a decision, a task and a milestone. Then create a new milestone and, in **Supersedes**, add all three with "Add…": they become **Superseded**.
- [ ] 10.2 In the detail of the new milestone, Evolution shows **"Supersedes:"** with the three entries (clickable). In the detail of one of them **"Superseded by:"** appears.
- [ ] 10.3 Remove an entry with the ✕ and save: that entry goes back to **Active**.
- [ ] 10.4 Have the same entry superseded by two different entries. Undo one of the two: the entry stays Superseded. Undo the other one too: it goes back to Active.
- [ ] 10.5 Try to have the older entry supersede the more recent one the other way around: IAGO asks whether to change the order of the chain.
- [ ] 10.6 With Claude: "the PX7 signature closes decision X and tasks Y and Z". The preview lists all the entries that become Superseded. Then in Settings › Claude **Undo**: links and states go back to how they were.
- [ ] 10.7 The graph and the project export show all the links.

## 10b. Importing JSON and pasting
- [ ] 10b.1 Drag a `.json` file into the window: it becomes a document, with the JSON neatly laid out (one value per line).
- [ ] 10b.2 *Import › From text*: paste a long JSON on a single line and import. The title is "Pasted JSON", the Mac stays responsive and the automatic suggestions, if they start, finish without blocking anything.
- [ ] 10b.3 Drag a `.csv` file and a `.yaml` file: they are imported as text. A `.zip` file shows "File type not supported".
- [ ] 10b.4 In a note: **⌘V**, **⌘C**, **⌘X**, **⌘A** and **⌘Z** work. Copy a JSON file in the Finder and paste it into the note with right-click › *Paste*: its text goes into the note, with no errors.
- [ ] 10b.5 With the window open, at the top there are the IAGO, Edit and Window menus; **⌘W** closes the window, **⌘,** opens Settings.

## 10c. Engine queue and memory (Mac with 16 GB if possible)
- [ ] 10c.1 On a Mac with less than 32 GB: Settings › Engine › *Automatic jobs* shows «Suggest automatically» and «Automatic summaries» off, with the line explaining why. On a 32 GB Mac they are on.
- [ ] 10c.2 With the switches off, a new transcribed call receives neither suggestions nor summaries on its own; *Find suggestions* and *Generate summary* work.
- [ ] 10c.3 Start *Generate summary* on a long call and, while it's writing, ask a question in *Ask*: the answer arrives without waiting for the end of the summary, and then the summary finishes anyway.
- [ ] 10c.4 While a call is being transcribed, ask a question in *Ask*: below 32 GB the answer arrives after the end of the transcription; the Mac stays responsive.
- [ ] 10c.5 On a Mac below 24 GB: Gemma 4 12B shows «Requires at least 24 GB of memory», and *Download* and *Use this* are disabled.
- [ ] 10c.6 Activity Monitor › Memory during a summary with Qwen 3.5 9B on 16 GB: memory pressure doesn't turn red and no app quits.

## 10d. Who produced the results
- [ ] 10d.1 Below a summary: «Summarized with Qwen 3.5 9B on the Mac» (or the model used).
- [ ] 10d.2 Each suggestion shows «Suggested by … on the Mac»; with Qwen 3.5 4B «small model» also appears, with the explanation on hover.
- [ ] 10d.3 Confirm a decision suggestion and open the key point: it says «Suggested by … on the Mac, confirmed by you».

## 10e. Mark moment with screenshot and shortcuts
- [ ] 10e.1 Settings › Permissions: the **Screen Recording** item is enabled with *Allow* (the first time macOS asks, then it goes to System Settings).
- [ ] 10e.2 During a recording with a shared presentation: **⌃⌥S** (even while Teams is in the foreground). The icon flashes; in the detail, at the end of the call, the **Screenshots** section shows the image at the right minute, with no IAGO windows.
- [ ] 10e.3 In the transcript the «Screenshot» line appears with the text read; searching for a word from the slide finds the call at that minute.
- [ ] 10e.4 *Generate summary*: if the slide contains an important fact, a point in the summary can cite it with its minute.
- [ ] 10e.5 **⌃⌥M** marks a moment, **⌃⌥R** stops the recording and restarts it; without a recording ⌃⌥M and ⌃⌥S show «No recording in progress».
- [ ] 10e.6 Settings › General › *Shortcuts in all apps*: change a combination, restore the default, disable it. A combination already used by another app shows «Used by another app».
- [ ] 10e.7 Open a screenshot and **Delete**: it disappears from the detail, from the transcript and from search.

## 10f. Claude makes summaries and suggestions
- [ ] 10f.1 In a call's detail: **Copy for Claude… › For the summary** with the project not readable: IAGO says so and offers to allow reading and writing; then it copies.
- [ ] 10f.2 Paste in Claude Desktop: Claude shows the preview with the points kept and discarded; after the OK the summary appears with **«Summarized by Claude»**.
- [ ] 10f.3 **Regenerate** asks for confirmation before replacing Claude's summary.
- [ ] 10f.4 *For the suggestions*: the suggestions appear as **«Recommended by Claude»** and are confirmed like the engine's.
- [ ] 10f.5 Ask Claude «summarize yesterday's call»: it finds the item among the recent items, and if there is more than one it asks which.
- [ ] 10f.6 Settings › Claude › *Changes*: undo Claude's summary and suggestions.
- [ ] 10f.7 With a call that has screenshots: without «Also share screenshot images with Claude» Claude reads only the text; enabling it, it also reads the images.

## 10g. Installation from DMG and updates
- [ ] 10g.1 On a clean user account or Mac: open `IAGO-x.y.z.dmg`, drag IAGO into Applications; at first launch "Open Anyway" only once.
- [ ] 10g.2 Update to the next version with Sparkle: no new block, the permissions stay.
- [ ] 10g.3 On a build compiled from source, Settings › General › Updates says that it updates with git.

## 10h. Recognizing voices
- [ ] 10h.1 Settings › Voices: the switch is off by default and the list is empty.
- [ ] 10h.2 Turn it on, record or import a call with at least two people on the other side (each speaking more than 10 seconds) and rename "Speaker 1" with an invented name: the voice appears in Settings › Voices with "1 call".
- [ ] 10h.3 Transcribe a second call with the same person: among the suggestions there is «Speaker N becomes …» with «Recognized by voice (similarity …%)». Confirm: the name changes and the voice goes up to "2 calls". Note the percentage, it is needed to calibrate the threshold.
- [ ] 10h.4 A different person doesn't receive that name (if it happens, note the percentage).
- [ ] 10h.5 Delete the voice: a single warning, then it disappears from the list. *Delete all voices…* asks for three steps (warning, DELETE, final confirmation).
- [ ] 10h.6 Turn off the switch: a new transcription no longer suggests names from the voice.

## 10i. Open work (1.1.0-beta and 1.2.0-beta)
First of all, if you are testing a build not yet merged into `main`: `scripts/try-branch.sh` opens it on a copy of the archive. To go back, close the test and reopen IAGO.
- [ ] 10i.1 Open a project for the first time: the window «… is in Manage mode» appears with the two modes explained. *OK* closes it and it comes back on the next visit; *Don't show again* removes it for that project. The project opens on the **Overview**; next to the name there is the *Manage mode ▾* pill (blue, columns icon) and the same icon is next to the project in the sidebar. From the pill choose *Track mode* (green, notebook): the Kanban and the *Show* menu disappear, the Overview becomes short. *Add* always offers the note, the six types and, at the bottom, *Import files and items…*.
- [ ] 10i.2 Create a task with an owner (try a name similar to an existing one: it must ask «Did you mean …?»), a due date of yesterday and two checklist lines: in the timeline the due date is red and 0/2 shows.
- [ ] 10i.3 Write someone in *Waiting for* with a date: the entry becomes *Waiting* and in the **Inbox** it appears under *Waiting on others*.
- [ ] 10i.4 In Manage *Mark as done*: green ✓, gray text not struck through; it leaves the Inbox and comes back with *Show closed*. In Track the task has a checkbox: check it from the timeline, from the Short overview or from the Inbox, then uncheck it (it goes back to open).
- [ ] 10i.5 Open question › *Answer…* with *Becomes a decision*: the decision is created and the question sits under it as «answered». Remove the link from the decision: the question goes back to open.
- [ ] 10i.6 Request › *Accept…* with two tasks: two tasks «derived from» the request are created, and the request shows as accepted. Another request › *Reject…* with a reason.
- [ ] 10i.7 In Manage: risk with high severity › *Became an issue*, then *Resolved*. In Track the same risk shows neither severity nor *Became an issue* (there is the Manage-details icon) and is closed with *Resolved*.
- [ ] 10i.8 In the detail of a task in Track there is the *Done* checkbox instead of the status, with owner, due date, *Waiting for* and checklist; no severity and no «derived from». Put the project back in *Manage*: the statuses, *More details* (priority, dependencies, estimate, start, recurrence) and the **Kanban** appear. Go back to *Track*: no data lost, and an icon flags the entries with Manage details.
- [ ] 10i.9 In Manage: a task that *depends on* another open one becomes Blocked and is unblocked when the other is done. A circular dependency is rejected with a clear message.
- [ ] 10i.10 Weekly recurring task with a due date: marking it done creates the next one, a week later, with the checklist to redo.
- [ ] 10i.11 A project's Kanban: it fills the whole window, clicking a card opens the panel on the right (✕ or Esc close it). Drag a card from the To do column to In progress (it changes the status) and to Waiting (it asks from whom and until when). Add the «To discuss» column and drag a card into it: the status doesn't change.
- [ ] 10i.12 Done column: with entries closed more than 14 days ago «Tasks closed 14+ days ago archived» appears with *Show all*; after the click the line becomes «Archive tasks closed 14+ days ago». Quit and reopen IAGO: the choice is remembered.
- [ ] 10i.13 Overview in Manage: create a project checklist and pin it (it appears in the Inbox); *Status report* writes a text from the key points (it appears in Activity) and can be copied.
- [ ] 10i.14 Settings › Projects: a project's mode can also be changed here. The tasks of a project in *Track* are in the Inbox and in the **Kanban of everything**, with the notebook icon next to the project name; move one to *In progress*: in the project it stays to be checked.
- [ ] 10i.15 Morning notification on with the time two minutes from now and an entry due today: the notification arrives with the counts and clicking it opens the Inbox.
- [ ] 10i.16 Transcribe or import a call in which a question is asked with no answer, a risk is named, the client asks for something and someone promises to send something «by Friday»: suggestions of the four types arrive, with the source sentence, and with the right date for Friday.
- [ ] 10i.17 With Claude Desktop: «list the project's open work», «create a task for Anna by November 10 with checklist…», then undo from Settings › Claude.
- [ ] 10i.18 Views bar: *Overview* and *Items*, each on its own, then Timeline · Kanban · Graph, all with an icon. *Items* shows the project's calls, emails and documents. *Show* (Everything, Items, Key points) appears only with Timeline and Graph; with the Kanban it reads «Show: Open work». In Track the pill has *Show the Graph*: when off, the Graph disappears from the bar.
- [ ] 10i.19 Choose Graph in one project and Kanban in another, switch project and come back: each reopens its last view.
- [ ] 10i.20 Sidebar: at the top **Inbox** in bold, with the tray icon and, if you have entries overdue or due today or suggestions to confirm, the badges with their number (see 10n); below it a line and **Unfiled items**.
- [ ] 10i.21 *Add › Import files and items…* in a project: drag a PDF into the area, then *From text* (the field opens) with a short text. Both end up in the project, not in Unfiled items. *Email without a file* opens the email window with the project already chosen.
- [ ] 10i.22 Open a client for the first time: the window asks for the mode of its projects. Choose Track: the projects for which you hadn't chosen a mode switch to Track, and a new project of the client is created in Track.
- [ ] 10i.23 With the Overview (or the Kanban) open, open «Ask IAGO»: the sidebar stays in place, with the Inbox below the window buttons. In the Kanban open a card: in the panel on the right the buttons («Mark as done», «Edit…») are whole and the date sits below.

## 10l. Italian and English (1.2.2-beta)
- [ ] 10l.1 With a new archive (`scripts/try-branch.sh --fresh`), the first screen asks «Lingua · Language». Choose English: IAGO restarts in English and setup starts again from the welcome screen, in English. The initial example is called Test Client, Test Pj. 1 and Test Pj. 2.
- [ ] 10l.2 Settings › General › Language: switch to Italiano. «Restart IAGO?» appears; *Restart now* reopens IAGO in Italian, with the initial example and the categories Progress review, Internal and Other back in Italian (SAL, Interna, Altro) (if you had not renamed them).
- [ ] 10l.3 In English, the guide (? Guide) is in English, with English screenshots.
- [ ] 10l.4 In English, generate the summary of a call and look for suggestions: summary and suggestions are in English, with English headings («In brief»), while quotes stay as they were spoken.
- [ ] 10l.5 In English, in search `category:` suggests the categories (`categoria:` works too).
- [ ] 10l.6 Documentation site: the language selector takes you from every page to the same page in English, and the Usage/Technical button stays in the chosen language.

## 10m. Window responsiveness and suggested tags (1.2.3-beta)
- [ ] 10m.1 With IAGO open for a few minutes and no jobs in Activity, Activity Monitor shows IAGO close to 0% CPU (also with Teams open and Teams mute reading on).
- [ ] 10m.2 The IAGO window drags as smoothly as the Finder's, and moving between Inbox, projects and views is immediate.
- [ ] 10m.3 With Teams mute reading on, join a Teams meeting: the call is recognized within about twenty seconds and the mute is read as before.
- [ ] 10m.4 With some tags already used in other calls, record a call on another topic and ask *Find suggestions*: the suggested tags concern only this call, each with the sentence it comes from (or a word said in the call); no tag of the other calls without ground.

## 10n. Inbox with two badges (1.2.4-beta)
- [ ] 10n.1 With one of your entries late, one with no owner and a few suggestions to confirm: next to **Inbox** there are a **red** badge with «!» and a **yellow** one with the sparkle. Hovering over each says what it counts.
- [ ] 10n.2 Open the Inbox: the **Do now** block has in its header the same red number as the sidebar, and its rows (late, today, no owner, overdue waits) are exactly that number.
- [ ] 10n.3 The **Suggestions to confirm** block has the same yellow number and shows the suggestions by item, three per item with *Show the other*. *Confirm* on a suggestion: the yellow number drops by one, in the Inbox and in the sidebar.
- [ ] 10n.4 *Dismiss these* on an item removes only its own; *Dismiss all…* asks for confirmation and removes them all. The yellow badge disappears.
- [ ] 10n.5 The entries for this week, with no date and the waits not yet overdue are in **Later**, with the grey number, and count in neither badge.
- [ ] 10n.6 Open a call with «Speaker 1» and type a name in its field: the border turns red, ⏎ and «Not saved» appear; the transcript does not change yet. Move to another item and back: the text is still there, red. *Esc* cancels it; *Return* (or ⏎) saves it and the transcript shows the name.
- [ ] 10n.7 Give a speaker the name «Antonello Prova», then in another call type «Lello»: IAGO asks whether it is «Antonello Prova». Answer *Yes*: the speaker takes that name. In a third call type «Lello» again: it suggests «Antonello Prova» right away. With a name with no similarities («Bruno Test») it asks nothing.
- [ ] 10n.8 In a call with three speakers give Speaker 3 the same name as Speaker 1: IAGO offers *Join*. Join: one field remains, the transcript shows that name also on Speaker 3's sentences, and below there is «Speaker 3 joined to …» with *Separate*. Rename Speaker 1: it changes on Speaker 3's sentences too. *Separate*: Speaker 3 goes back as it was.
- [ ] 10n.9 On a call with speakers still «Speaker N» press *Generate summary* (or *Regenerate*): IAGO asks whether to name them first. *Name them first* opens the transcript with the cursor in the first unnamed field; *Go ahead as is* starts the summary. With all speakers named, the question does not appear.

## 10o. Transcripts side by side and Claude tip (1.2.5-beta)
- [ ] 10o.1 On a call already transcribed by IAGO, *Attach Teams transcript…* with a test `.vtt`: the **★ IAGO** and **Teams** tabs appear. IAGO's stays the main one and its minutes start the audio.
- [ ] 10o.2 In the **Teams** tab the minutes are grey text, without links, and *Listen from here* in the right-click menu is off. Screenshots do not appear among the lines.
- [ ] 10o.3 On the Teams tab *Make main* (see 10p): the tabs swap. *Regenerate* the summary: it uses Teams' text, and a click on a minute in the summary does not start the audio.
- [ ] 10o.4 *Delete this transcript…* on the Teams tab, with confirmation: only IAGO's stays and the Teams speaker names disappear. Repeat with IAGO's transcript: Teams' stays and becomes the main one.
- [ ] 10o.5 On a call with only Teams' transcript, *Transcribe*: IAGO transcribes and its transcript becomes the main one, with Teams' beside it.
- [ ] 10o.6 On a Mac with 16 GB or less, in a call without a summary the tip «have Claude write the summary» appears. On a project not allowed for Claude the button is *Allow and ask Claude*. Without a connection to Claude it is *Connect Claude…*, which opens Settings › Claude.
- [ ] 10o.7 *Ask Claude for the summary*: the request is on the clipboard and Claude opens. Paste it: Claude writes the summary, the preview asks for the OK and afterwards the summary is in the item card.
- [ ] 10o.8 *Use the Mac's engine* on a project: the tip no longer appears there, but it does on the others. In Settings › Engine › *Summaries and suggestions* choose **Claude**: the automatic jobs turn off and the tip appears everywhere.

## 10p. Main transcript and search in both (1.2.6-beta)
You need a call with IAGO's and Teams' transcripts (10o.1), and a word that is only in Teams' (for example a name spelled differently).
- [ ] 10p.1 In the Transcript section the first tab is **★ IAGO**. When it is open, below the tabs there is «★ Main · used for summaries, suggestions and exports». On the **Teams** tab there is instead *Make main* with «Search looks here too. Summaries, suggestions and exports use «IAGO»».
- [ ] 10p.2 Search for the word that is only in Teams': the call shows once, the passage says «in the Teams transcript» and its minute is grey. Open it: the Teams tab opens and the audio does not start.
- [ ] 10p.3 Search for a word that is in both: the call shows once, without a label, and the passage opens the IAGO tab with the audio at that point.
- [ ] 10p.4 With a summary already written, on the Teams tab *Make main*: IAGO asks first and reminds you that the summary stays as it is and that Teams' minutes are not linked to the audio. Confirm: the ★ moves to Teams, which becomes the first tab, and above the summary appears «Written from the IAGO transcript; the main one is now Teams» with *Regenerate*.
- [ ] 10p.5 *Regenerate*: the warning goes away and below the summary there is «from the Teams transcript». Now search for a word that is only in IAGO's transcript: the passage says «in the IAGO transcript».
- [ ] 10p.6 On a call without a summary *Make main* swaps at once, without questions.

## 11. Tests already queued from previous phases
- [ ] 11.1 "Tidy up text" on 2-3 dictated notes: the text stays faithful (names, numbers and dates unchanged).
- [ ] 11.2 Transcription quality on real calls with several people.
- [ ] 11.3 Acceptance tests of Phases 1-2 (2-hour recording, headphones connected and disconnected, Mac sleep, crash).
