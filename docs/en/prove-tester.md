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
- [ ] 3e.5 Press **Search** (⌘F) and in the simple search type `#` or `category:`: the tags or categories to open appear.
- [ ] 3e.7 On a Mac without IAGO (or with a new archive): once the setup is done, the sidebar shows **Atoms**, **Poldo S.p.A.** and **Sanna TheBest s.r.l.** with their projects, and *Headless customer portal* pinned, full of calls, emails, documents and key points. *Settings › Projects › Remove the example* removes them all and they don't come back after a restart. They don't appear on an archive already in use.
- [ ] 3e.8 Right-click a stream › **Pin to top**: it appears in "Pinned" with the project name below; **Unpin from top** removes it.
- [ ] 3e.6 In an item's detail, clicking a tag opens all the items with that tag. Next to the category there is no icon: all the items of a category are opened from Categories and tags.

## 3f. Help, tour and glossary
- [ ] 3f.1 At the first launch after setup the introduction appears (see 10s). "Don't show again" turns it off; you can see it again from Help › Getting started.
- [ ] 3f.2 "IAGO Help" opens from the menu bar menu and from the "?" in the window; every topic can be read and the "Open Settings" buttons work.
- [ ] 3f.2b The **? Guide** button at the top left, next to Settings, opens the full-page guide: chapters on the left, text and images, search, "← Previous / Next →".
- [ ] 3f.2c Settings › **Help**: "Open the guide", "See the introduction again" and "Show the introduction at launch" work.
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
- [ ] 6.9 **Change context ▾** offers *Add projects…*, *Narrow context…*, *Global context* and *Follow the open section*. Before asking, the choice only changes the context.
- [ ] 6.10 After a question, change the context: a new conversation opens in the chosen context with the same question; the previous one stays in the list.
- [ ] 6.11 With a chosen context the strip says "Chosen by you: stays when you change section"; *Follow the open section* brings it back to the open section.
- [ ] 6.12 An answer with no cited sources: with **Change context ▾ › Global context** the same question is asked again on the whole memory.
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
- [ ] 10l.1 With a new archive (`scripts/try-branch.sh --fresh`), the first screen asks «Lingua · Language». Choose English: IAGO restarts in English and setup starts again from the welcome screen, in English. The example projects are in English (Headless customer portal…).
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

## 10q. Sharing an item (1.2.7-beta)
- [ ] 10q.1 On a transcribed call with audio, *Share…*: the list shows Card, Transcript, Audio (with the size) and, if present, Separate tracks, Screenshots, Other transcript. Card and Transcript are already ticked.
- [ ] 10q.2 *Share…* with Card and Transcript: the Mac's Share menu opens. Choose Mail: the message has the two `.md` files. The card has summary, key points and notes, without the transcript; the transcript has the speakers' names.
- [ ] 10q.3 Also tick Audio and *A single .zip file*, then *Save to a folder…*: the folder has a single `.zip` with the item's folder and the three files, and the Finder shows it.
- [ ] 10q.4 On an imported email: the parts are Card, Text and Original email (.eml); the `.eml` opens in Mail.
- [ ] 10q.5 Settings › Privacy › access log: there is an export «share» row for each share. While the files are prepared, the share shows in Activity.

## 10r. Several people in the room, those present and mandatory updates (1.2.8-beta)
You need two real people in the same room (invented names in written tests).
- [ ] 10r.1 Without any open call, *Start recording* and talk, two of you, for at least a minute each. Transcribe: whoever spoke more is «Me», the other voice is «Room 2», without turning anything on.
- [ ] 10r.2 During a test call with another person next to you, without turning anything on: after the transcription the voice next to you is under «Me» and the card shows «On the microphone I heard another voice…» with *Separate the voices*. Press it: the call is transcribed again and «Room 2» appears.
- [ ] 10r.3 During a recording, icon menu › *Several people here in the room* (it stays ticked). After Stop the panel has *Several people in the room* already on and the transcription separates the voices.
- [ ] 10r.4 In the panel after Stop write in *Present* «Bruno Test, Carla Prova» and Return: two names appear. In the card, next to «Room 2», the button for those present offers the two names; choosing one renames the speaker. A known name written in lowercase takes the known spelling.
- [ ] 10r.5 With *Recognize voices* on, name «Room 2»; in another meeting with the same person in the room the suggestion with that name arrives.
- [ ] 10r.6 *Share* and *Export*: the Markdown card shows «Presenti: …».
- [ ] 10r.7 (Only with a test release marked mandatory) the icon menu shows «Mandatory update …: install it by …» and *Update now…*; after 2 days *Start recording* asks to update and transcriptions, summaries and suggestions do not start.

## 10s. Introduction (1.2.9-beta)
- [ ] 10s.1 With a new archive (`scripts/try-branch.sh --fresh` or a test user account), once the setup is done the introduction opens: at the top «IAGO, always on your shoulder. Meeting after meeting.», ten steps, «1 of 10».
- [ ] 10s.2 Every step has its screenshot; step 2 has the «It recognizes the meeting» and «After Stop» tabs, step 5 Overview, Timeline, Kanban and Graph. In English the screenshots are the English ones.
- [ ] 10s.3 The buttons take you to the right place: example project (on step 5 in the view of the chosen tab), Import, Inbox, Key points, Ask IAGO, Settings › Claude and › Privacy, guide.
- [ ] 10s.4 First steps: import a document with the introduction open and the row ticks itself; «x of 6 done» goes up.
- [ ] 10s.5 Close with *Start* without *Don't show again*: at the next launch it opens again. With *Don't show again*, or with all first steps done, it does not; *See the introduction again* in Help › Getting started and in Settings › Help reopens it.

## 10t. Item detail (1.2.11-beta)
- [ ] 10t.1 Open a call: under the title client › project and date · duration · type, then the tiles. Each tile has one value only; Transcript says IAGO, Teams or IAGO + Teams; the tiles of empty sections are dashed.
- [ ] 10t.2 A click on a tile opens the section (even if it was closed) and takes you there, with its title just under the sticky bar.
- [ ] 10t.3 Scroll down: the sticky bar appears (title, below it client › project · date · duration, tiles in miniature) with the section you are in highlighted; at the bottom right ↑ above «Ask IAGO», without overlapping. Hide «Ask IAGO» with its ✕: ↑ moves down to its place. ↑ goes back to the top and bar and ↑ disappear.
- [ ] 10t.4 Close the Transcript in one call and leave it open in another: each stays as it was. In Settings › General › Item detail set Transcript to Closed: a call never touched opens it closed; *Reapply to all items…* brings every call back to this choice. Files is always open.
- [ ] 10t.5 A call without bookmarks, notes or links: those sections are just a dashed header with the sentence; *Add note* and *Link to…* work from there.
- [ ] 10t.6 A call with bookmarks and screenshots: coloured ticks on the player; below one moment at a time with ‹ › and «N of M»; the minute plays the audio from there; while listening the moment follows the audio. The same moments are in the transcript at their minute. Turning off the two checkboxes in Settings makes them disappear.

## 10u. Overview, Activity and fixes (1.2.12-beta)
- [ ] 10u.1 A project's Overview in Manage: boxes in two columns with no holes even when a box has many more entries; the tiles at the top stay in view while scrolling; a click on a tile takes you to the box and makes it glow, even when already in view; empty boxes are a dashed header; *Latest decisions and milestones* is there.
- [ ] 10u.2 A click on an entry opens the panel on the right and the boxes switch to one column; ✕ or Esc closes it and two columns come back. With a narrow window one column and the tiles wrap, with no text cut off.
- [ ] 10u.3 A project in Track: the Short overview has the panel on the right at once, with the logo and no ✕; opening an entry the panel shows it.
- [ ] 10u.4 Activity: across the window, no «No item selected»; tiles at the top taking you to the sections; *Last 7 days* and *Ready to work* on the right (below with a narrow window); *Open* shows the item in the panel.
- [ ] 10u.5 Sidebar: the mode icon is green (Track) or blue (Manage); a click opens the choice and changing it changes the project. «Categories and tags» opens on click.
- [ ] 10u.6 *New* in Key points, with the window not full screen: the sheet is fully visible, the kinds are pills on several lines, the labels in one column.

## 10v. Style, light and dark (1.2.13-beta)
- [ ] 10v.1 Next to Settings there is the appearance menu: *Automatic* follows the Mac, *Light* and *Dark* change every window at once and stay after a restart.
- [ ] 10v.2 In light there are no large white areas: pages, lists (Recent, Unfiled items), top bars and boxes are light greys; the sidebar is darker than the pages.
- [ ] 10v.3 Titles and text are neutral; the kind's colour is in the bar, the box icon and the tile dot; in rows icons are grey and turn red only for overdue, blocked or high risk. A thin thread sits under every box title.
- [ ] 10v.4 *Add* in Key points: the sheet says "Add" and the kind in a tile; a click on the tile changes kind; the menu has the dots and a line between decisions/milestones and open work.
- [ ] 10v.5 A call with bookmarks and screenshots: in the transcript they sit on a veil of their colour with a thread on the left, the screenshot with its thumbnail.
- [ ] 10v.6 Kanban with columns in boxes and the status line under the title; Activity in one column with *Last 7 days* and *Ready to work* side by side; Categories and tags across the window.

## 10w. Inbox in two halves
- [ ] 10w.1 With entries and suggestions, *Do now* takes the top half and *Suggestions to confirm* the bottom half; each scrolls on its own and the bar shows even with "Show scroll bars: automatically" on the Mac.
- [ ] 10w.2 When more entries are below, *N more* appears at the bottom right with three dots that light up about every 10 seconds; scrolling to the end makes it disappear.
- [ ] 10w.3 Once every suggestion is confirmed or dismissed, the bottom box shrinks to its header and *Do now* takes all the room; *Later* and *Show closed* sit at the bottom of *Do now*.
- [ ] 10w.4 Dragging the handle between the two boxes changes their height; after quitting and reopening IAGO it stays as it was; a double click goes back to half and half.
- [ ] 10w.5 A click on an item's box in *Suggestions to confirm* highlights it and opens all its suggestions on the right; *Confirm*, *Dismiss*, *Confirm all* and *Dismiss these* update the numbers at once, and the item with no suggestions left leaves the list. *Open item* opens its page.
- [ ] 10w.6 On an archive where you never moved the divider, the middle and right columns are half and half in every place. Widen the middle column in *Unfiled items*: in *Inbox* and *Recent* it stays as it was, and back in *Unfiled items* you find your width, also after restarting IAGO.
- [ ] 10w.7 In a call's card the sections are, in order: Audio, Bookmarks, Screenshots, Summary, Transcript, Suggestions, Key points, Notes, Links, Files; the tiles at the top follow the same order.
- [ ] 10w.8 Drag the title of *Notes* (or its ≡ handle) upwards: all the sections close, «Drop the section where you want it…» appears at the top, *Notes* is highlighted and the others move as you pass. Drop it on *Summary*: *Notes* stays there, the sections go back to open or closed as before and the tiles reorder. Open another call and an email: the order is the same, also after restarting IAGO. Dropping outside the card ends the reordering by itself.
- [ ] 10w.9 *Settings › General › Item detail › Restore the section order* (enabled only after a reorder) brings back the standard order in the next card you open.
- [ ] 10w.10 Sidebar: no «Projects» title; on the right above *Pinned* there is *Add*, which opens *Add:* with *Client…* and *Project…*, and both work. At the bottom there is only *Trash*, like the entries at the top, and a click opens it.
- [ ] 10w.11 Hovering a client shows only **+**: it opens *New project* with that client written and not editable, and the project created ends up under that client. From a project's right-click, *New stream…* opens its window.
- [ ] 10w.12 With a narrow sidebar, stay two seconds on a project's truncated name: the whole name appears, disappears when you leave, and a click on the row still opens the project.
- [ ] 10w.13 The line between the middle and right columns stops under the toolbar: at the top there is only the sidebar's line, in light and dark.

## 10x. Categories and tags, context, search, microphone, voices and Claude (1.2.15-beta)
- [ ] 10x.1 *Categories and tags*: three columns (labels, items, detail). On the left the *Categories* and *Tags* boxes close and open again; in the tag search Return adds the first match. Choose a category and two tags: in the middle only the items with the category and **both** tags remain; ✕ on a tag removes it, *Reset* removes everything. Right click on a tag: you put it in *Pinned*.
- [ ] 10x.2 Drag the two handles between the columns: the widths stay after restarting IAGO; a double click on a handle goes back to the initial widths.
- [ ] 10x.3 *Ask IAGO* from a project: the context is the project and says "Follows the open section". *Change context › Add projects…*: tick a second project (also with the client's box) and *Apply*: two chips appear, the conversation starts again with the last question and sources come from both. The context now says "Chosen by you" and stays when changing section and restarting IAGO.
- [ ] 10x.4 ✕ on a chip removes that project; *Narrow context…* keeps only the ticked projects (off with a single project); *Global context* moves to the whole memory; *Follow the open section* goes back to the basic behaviour.
- [ ] 10x.5 At the top right there is *Search*, no longer the field: a click or ⌘F opens *Simple search* in the right pane with the explanation, the cursor in the field and the ✕ (also Esc) to close it. Search a word: results stay in the pane and a click opens the item in the detail beside it. `#` and `category:` show the suggestions.
- [ ] 10x.6 From search, *Ask IAGO* at the bottom moves to the chat in the same pane; in the chat the magnifying glass goes back to search. While either pane is open, the round *Ask IAGO* button at the bottom right disappears.
- [ ] 10x.7 In the chat, the *Full window* button: the sidebar, the conversation list and the conversation in the middle remain; a source opens on the right with its ✕. *Back to a pane* returns as before, with the same conversation. A click on a sidebar section leaves the full-window view. Closing and opening the chat again, the conversation is still there.
- [ ] 10x.8 Sidebar: a click on a project's mode icon opens the choice; the explanations of Track and Manage can be read in full, without ellipses.
- [ ] 10x.9 Record a test call and, while recording, unplug the microphone (or choose in System Settings an input that sends no audio): within 2-3 seconds the dot on IAGO's icon turns yellow, the panel *The microphone is not recording* appears and the menu says *No audio from the microphone*. Plug it back: it turns red again and the panel goes away. *Ignore* closes the panel, which does not come back until the microphone resumes and stops again; *Choose the microphone* opens Settings › Audio.
- [ ] 10x.10 While recording, stay silent for more than 30 seconds while someone talks in the Mac's audio: the dot stays red, the panel *The microphone does not hear your voice* appears only once and the menu has the silent track line.
- [ ] 10x.11 On a new archive Settings › Voices has *Recognize voices across calls* on, and *Your name* at the top. Change the name and press Return (or leave the field): below it shows how many calls were updated, and in those calls your voice has the new name.
- [ ] 10x.12 In a transcribed call, type in a speaker's field the first letters of a name already used: the list of known names appears; choosing one and pressing Return, ✓ or clicking elsewhere saves the name, without a red border. In a call transcribed before voices were on, a line under the names says to use *Transcribe again*. After *Transcribe again* and naming the speaker, the voice appears in *Known voices*.
- [ ] 10x.13 Next to your voice appears **You**, in the transcript and in the names: hovering over it, in a recorded call it says it is the microphone's voice recorded with IAGO; in an imported audio file, after giving a speaker your name, it says it is an imported file with your name.
- [ ] 10x.14 An item without a summary, on a Mac with more than 16 GB: at the bottom of Summary, after *Generate summary*, there is *Alternative: write the summary with Claude* in neutral colours, with the four steps (project, connection, consent, request) and the done mark on those already in place. On a project already in Claude (Claude icon in the sidebar) step 3 says it is all set. Every *how?* opens the guide at the Claude chapter.
- [ ] 10x.15 *Don't show again*: a strip "Alternative: you can also make the summary with Claude." remains with *See how*, which opens the box again for that item; opening another item the strip comes back.
- [ ] 10x.16 With Claude Desktop open, make a project readable by Claude (Settings › Claude, or *Allow* in the box): *Restart Claude Desktop* appears; *Restart Claude* quits and reopens Claude Desktop, which then sees the project. With Claude Desktop closed the alert does not appear.

## 10y. DMG and installation instructions (ADR-0097)
To be done on a Mac or user account where IAGO has never been installed, with the DMG downloaded from the release (not copied from another Mac).
- [ ] 10y.1 Open `IAGO.dmg`: the window has the background with "Drag IAGO to Applications", IAGO on the left and Applications on the right, with the three coloured arrows between them; at the bottom, in the yellow band, there is *Leggimi - Read me*. Repeat with the Mac in dark mode and check that the icon names are readable.
- [ ] 10y.2 Open *Leggimi - Read me*: it is in the Mac's language and the button at the top switches between Italian and English. *Show me the steps* leads to the four steps, *Allergic to menus?* leads to the command; *Copy* copies the command.
- [ ] 10y.3 Drag IAGO to Applications and open it: the warning appears. Follow the *Privacy & Security › Open Anyway* steps: IAGO opens, and the following times it opens without a warning.
- [ ] 10y.4 On another clean account or Mac, after dragging IAGO, use the Terminal command instead: it asks for the password, then IAGO opens without a warning.
- [ ] 10y.5 The "Download IAGO.dmg" link at the top of the README downloads the latest version.
- [ ] 10y.6 On a clean Mac, after the download: `xattr -d com.apple.quarantine ~/Downloads/IAGO.dmg` in Terminal (no password), then the DMG opens; IAGO dragged to Applications opens with no warning at all. *Leggimi - Read me* opens with its content, not white.

## 10z. Collect mode (ADR-0098)
- [ ] 10z.1 Click on a project's mode icon: there are three cards, Collect (orange box), Track and Manage. Choose Collect: in the sidebar the icon becomes the box.
- [ ] 10z.2 In the project in Collect there are only *Items* and *Timeline*, without *Show*; the Timeline shows only the items. *Add* offers the note and the import, not key points.
- [ ] 10z.3 In a call of the project: bookmarks and screenshots are there, in the transcript too, but without *Becomes a decision…*; the card has no *Key points*. *Find suggestions* proposes names, tags and links, no decision or task.
- [ ] 10z.4 Inbox: the line «From projects in Collect mode only the suggestions to confirm arrive here» appears; the suggestions of those calls are there, their open work is not.
- [ ] 10z.5 On a Mac with 16 GB or less and automatic summaries on, a new call of the project gets no summary by itself; *Generate summary* writes it.
- [ ] 10z.6 Put the project back in Manage: the key points written earlier become visible again.
- [ ] 10z.7 From Claude, ask to add a decision to the project in Collect: the tool refuses and explains how to change mode.

## 10za. Deleting projects, clients and streams (ADR-0099)
On a test archive, with a project that has two streams, a few items, a note and a key point.
- [ ] 10za.1 Right-click the project › *Delete project…*: the dialog says how many items, transcripts and notes it holds and lists the two streams. *Move to Trash* is already chosen and has its explanation.
- [ ] 10za.2 *Move to Trash*: the project and its streams disappear from the sidebar; its items are not in Recent, searching a word of the note finds nothing, the key point is neither in Inbox nor in Key points. The number next to *Trash* goes up by one.
- [ ] 10za.3 In the Trash, *Projects* section: the project is there with «deleted in 30 days». *Restore*: the project comes back as it was, with streams, items, note and key point, and under the same client.
- [ ] 10za.4 *Delete project…* again, choose *Delete permanently* › *Continue*: it asks to type DELETE (OK stays off until it is typed), then the last confirmation. The project is not in the Trash.
- [ ] 10za.5 The same from Settings › Projects › *Delete…*: same dialog.
- [ ] 10za.6 Right-click a client with projects › *Delete client…*: it lists the projects with their streams. Confirm: the projects are in «No client», with everything in them.
- [ ] 10za.7 Right-click a stream › *Delete stream…*: it says how many items, key points and notes lose the label; afterwards they stay in the project.
- [ ] 10za.8 Put an item of the project in the Trash, then the project; restore only the item: it goes back to *Unfiled items*.

## 11. Tests already queued from previous phases
- [ ] 11.1 "Tidy up text" on 2-3 dictated notes: the text stays faithful (names, numbers and dates unchanged).
- [ ] 11.2 Transcription quality on real calls with several people.
- [ ] 11.3 Acceptance tests of Phases 1-2 (2-hour recording, headphones connected and disconnected, Mac sleep, crash).
