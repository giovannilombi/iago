# Emails and documents

## Importing
- **Drag** files into the window or into *Import*: PDF, Word, text files, images (with text recognition), emails (.eml, .msg), audio and video, Teams transcripts, JSON, CSV and other text files.
- **Paste** a text or an email from *Import*. A pasted or imported JSON is shown neatly, one value per line.
- **Add to IAGO** from any app: select some text › right-click › *Services* › *Add to IAGO*.
- From the menu of the IAGO icon ![icona di IAGO](/icona.svg): **Import files…**.
- **From inside a project:** *Add › Import files and items…*. Drag, choose from the Mac, paste or type a text, and everything goes straight into that project (and into the streams you choose), without passing through *Unfiled items*.

Emails are recognized (sender, recipients, conversation) and IAGO suggests the project based on the people.

## Watched folders
In **Settings › Email and people › Add folder** choose a folder: IAGO imports on its own, only once, the emails that land in it. Meeting invitations are skipped, and you can add **rules** to exclude emails or assign them to a project.

### Saving Outlook mail automatically (Power Automate)
1. Open **Power Automate** with your work account and create an automated flow *When a new email arrives (V3)*.
2. Add the action *Export email (V2)* and then *Create file* in **OneDrive**, in the folder IAGO watches, with a name ending in `.eml`.
3. Repeat with *Sent Items* for outgoing emails.

OneDrive brings the files to the Mac and IAGO imports them.
