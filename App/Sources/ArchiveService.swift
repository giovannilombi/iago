import Foundation
import IAGOCapture
import IAGOCore
import IAGOIngest
import IAGOStore
import UniformTypeIdentifiers
import os

/// Bridges capture and the encrypted archive: the app is the only module that sees both (spec 5.1).
/// Blocking work (encryption, conversion) runs off the main actor with `.utility` priority.
final class ArchiveService: Sendable {
    let archive: Archive
    let paths: StoragePaths
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "archive")

    static let backupIncludedKey = "include_in_time_machine"

    init(paths: StoragePaths) throws {
        self.paths = paths
        let database = try AppDatabase.open(at: paths.database)
        archive = try Archive(database: database, itemsRoot: paths.items, keyStore: KeychainMasterKeyStore())
        let included = try archive.setting(Self.backupIncludedKey) == "1"
        try Archive.setExcludedFromBackup(paths.root, excluded: !included)
    }

    private func background<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .utility) { try body() }.value
    }

    /// Encrypts one finalized recording into the archive.
    func archiveFinalized(_ folder: URL) async throws -> Item {
        let archiver = RecordingArchiver(archive: archive)
        return try await background { try archiver.archive(folder: folder) }
    }

    /// At launch: archives recordings finalized but not yet encrypted (crash between the two steps) and
    /// the phase 0 plaintext recordings (ADR-0029). Returns the failures, already logged.
    func archivePending() async -> [String] {
        var failures: [String] = []
        for root in [paths.finalized, paths.legacyRecordings] {
            for folder in RecordingArchiver.pendingFolders(in: root) {
                do {
                    let item = try await archiveFinalized(folder)
                    logger.notice(
                        "Archived \(item.id, privacy: .public) from \(root.lastPathComponent, privacy: .public)")
                } catch {
                    logger.error("Archiving \(folder.lastPathComponent, privacy: .public) failed: \(error)")
                    failures.append(folder.lastPathComponent)
                }
            }
        }
        let legacy = paths.legacyRecordings
        if let remaining = try? FileManager.default.contentsOfDirectory(atPath: legacy.path),
            remaining.allSatisfy({ $0.hasPrefix(".") })
        {
            try? FileManager.default.removeItem(at: legacy)
        }
        return failures
    }

    /// Generic import ("Importa…"): audio and video become recordings to transcribe (only the audio is
    /// kept), meeting transcripts (Teams .vtt/.docx) become the transcript of the matching recording or an
    /// item of their own (ADR-0033), any other readable file becomes material to classify (document with
    /// its Markdown). Originals are never touched.
    func importFiles(_ urls: [URL]) async -> [(name: String, result: Result<Item, Error>)] {
        var media: [URL] = []
        var transcripts: [(url: URL, transcript: Transcript)] = []
        var documents: [URL] = []
        var results: [(String, Result<Item, Error>)] = []
        for url in urls {
            if let transcript = try? TeamsTranscript.parse(url, itemID: "") {
                transcripts.append((url, transcript))
            } else if Self.isMedia(url) {
                media.append(url)
            } else if ContentExtractor.canExtract(url) {
                documents.append(url)
            } else {
                results.append((url.lastPathComponent, .failure(ExtractionError.unsupported(url.lastPathComponent))))
            }
        }
        // Each transcript goes with the recording of the same meeting: the only one imported, or the one
        // with the most similar name.
        var pairs: [URL: (url: URL, transcript: Transcript)] = [:]
        var unpaired: [(url: URL, transcript: Transcript)] = []
        for entry in transcripts {
            let candidates = media.filter { pairs[$0] == nil }
            if candidates.count == 1, media.count == 1 {
                pairs[candidates[0]] = entry
            } else if let match = candidates.max(by: {
                Self.nameAffinity($0, entry.url) < Self.nameAffinity($1, entry.url)
            }),
                Self.nameAffinity(match, entry.url) >= 6
            {
                pairs[match] = entry
            } else {
                unpaired.append(entry)
            }
        }
        for url in media {
            let result = await importMedia(url, transcript: pairs[url])
            results.append((url.deletingPathExtension().lastPathComponent, result))
        }
        for entry in unpaired {
            let result = await importTranscriptOnly(entry.url, entry.transcript)
            results.append((entry.url.deletingPathExtension().lastPathComponent, result))
        }
        for url in documents {
            let result = await importDocument(url)
            results.append((url.deletingPathExtension().lastPathComponent, result))
        }
        return results
    }

    static func isMedia(_ url: URL) -> Bool {
        if let type = UTType(filenameExtension: url.pathExtension.lowercased()),
            type.conforms(to: .audio) || type.conforms(to: .movie) || type.conforms(to: .audiovisualContent)
        {
            return true
        }
        // Wrong extension (e.g. WhatsApp voice notes saved as .jpg/.mp3): look at the content.
        return AudioFileConverter.sniffedExtension(of: url).map {
            ["mp4", "m4a", "mov", "mp3", "wav", "aiff", "caf"].contains($0)
        }
            ?? false
    }

    /// Length of the common prefix of the two file names (lowercased, without extension).
    static func nameAffinity(_ a: URL, _ b: URL) -> Int {
        let x = Array(a.deletingPathExtension().lastPathComponent.lowercased())
        let y = Array(b.deletingPathExtension().lastPathComponent.lowercased())
        return zip(x, y).prefix { $0 == $1 }.count
    }

    private func importMedia(_ url: URL, transcript: (url: URL, transcript: Transcript)?) async -> Result<Item, Error> {
        let name = url.deletingPathExtension().lastPathComponent
        let converted = paths.scratch.appendingPathComponent("\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: converted) }
        logger.notice("Import of \(url.lastPathComponent, privacy: .public): converting")
        do {
            let output = try await AudioFileConverter.convertToM4A(url, destination: converted)
            let date = AudioFileConverter.creationDate(of: url)
            let archive = self.archive
            let item = try await background {
                let item = try archive.importAudio(
                    output.file, title: name, occurredAt: date, durationSec: output.duration)
                if let transcript {
                    try Self.attach(transcript.transcript, from: transcript.url, to: item.id, archive: archive)
                }
                return item
            }
            logger.notice(
                "Import of \(url.lastPathComponent, privacy: .public): archived as \(item.id, privacy: .public)")
            return .success(item)
        } catch {
            logger.error("Import of \(url.lastPathComponent, privacy: .public) failed: \(error)")
            return .failure(error)
        }
    }

    /// A transcript without its recording is still precious: it becomes an item of its own.
    private func importTranscriptOnly(_ url: URL, _ transcript: Transcript) async -> Result<Item, Error> {
        let archive = self.archive
        let name = url.deletingPathExtension().lastPathComponent
        let date = AudioFileConverter.creationDate(of: url)
        do {
            return .success(
                try await background {
                    let item = try archive.createItem(
                        title: name, occurredAt: date, source: .import, status: .transcribed,
                        durationSec: transcript.segments.last?.end)
                    try Self.attach(transcript, from: url, to: item.id, archive: archive)
                    return item
                })
        } catch {
            logger.error("Import of \(url.lastPathComponent, privacy: .public) failed: \(error)")
            return .failure(error)
        }
    }

    /// ADR-0033: the imported transcript becomes the item's transcript; the original is kept too.
    static func attach(_ transcript: Transcript, from url: URL, to itemID: String, archive: Archive) throws {
        var transcript = transcript
        transcript.itemId = itemID
        try archive.attachImportedTranscript(
            try transcript.encoded(), speakers: transcript.speakers.map { ($0.id, $0.label) }, original: url, to: itemID
        )
        try archive.indexTranscript(transcript, itemID: itemID)
        try TextAssets.render(archive: archive, itemID: itemID, transcript: transcript)
    }

    /// Pasted or typed text (FR-30, "Importa › Da testo"): a document whose original is the text itself, as `.md`.
    func importText(_ text: String, title: String) async throws -> Item {
        let archive = self.archive
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name =
            trimmed.isEmpty
            ? String(
                text.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) }?
                    .prefix(80) ?? "")
            : trimmed
        // Pasted JSON is shown indented, like an imported .json file; its first line ("{") is no title.
        let json = ContentExtractor.jsonMarkdown(text)
        let title =
            trimmed.isEmpty && json != nil
            ? String(localized: "JSON incollato") : name.isEmpty ? String(localized: "Testo incollato") : name
        let folder = paths.scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let file = folder.appendingPathComponent("text.md")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
        return try await background {
            try archive.importDocument(file, isImage: false, markdown: json ?? text, title: title, occurredAt: Date())
        }
    }

    private func importDocument(_ url: URL) async -> Result<Item, Error> {
        let archive = self.archive
        let name = url.deletingPathExtension().lastPathComponent
        let date = AudioFileConverter.creationDate(of: url)
        do {
            return .success(
                try await background {
                    let extraction = try ContentExtractor.extract(url)
                    let isImage =
                        UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .image) ?? false
                    return try archive.importDocument(
                        url, isImage: isImage, markdown: extraction.markdown, title: name, occurredAt: date)
                })
        } catch {
            logger.error("Import of \(url.lastPathComponent, privacy: .public) failed: \(error)")
            return .failure(error)
        }
    }

    // MARK: Emails (FR-180…185, ADR-0040)

    /// `.eml` / `.emlx`, or a promised file without extension whose first lines are email headers.
    static func isEmail(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["eml", "emlx"].contains(ext) { return true }
        guard ext.isEmpty || ext == "txt", let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let head = String(decoding: (try? handle.read(upToCount: 2048)) ?? Data(), as: UTF8.self).lowercased()
        return ["received:", "return-path:", "mime-version:", "message-id:", "from:"].contains { head.hasPrefix($0) }
            && head.contains("\nsubject:")
    }

    /// Reads an email file. Apple Mail's `.emlx` starts with the byte count of the message on its own line.
    func readEmail(_ url: URL) throws -> EmailImportDraft {
        var data = try Data(contentsOf: url)
        if url.pathExtension.lowercased() == "emlx", let newline = data.firstIndex(of: 10),
            Int(String(decoding: data[data.startIndex..<newline], as: UTF8.self).trimmingCharacters(in: .whitespaces))
                != nil
        {
            data = data[data.index(after: newline)...]
        }
        let message = try EmailParser.parse(Data(data))
        let addresses = ([message.from].compactMap { $0 } + message.to + message.cc).map(\.address)
        let suggestions = (try? archive.projectSuggestions(for: addresses)) ?? []
        let classification = try? archive.classifyEmail(
            addresses: addresses, subject: message.subject, inReplyTo: message.inReplyTo,
            references: message.references)
        let duplicate = try message.messageID.map { try archive.emailExists(messageID: $0) } ?? false
        return EmailImportDraft(
            message: message, original: Data(data), fileName: url.lastPathComponent, suggestions: suggestions,
            classification: classification, alreadyImported: duplicate)
    }

    /// Emails imported before a better body conversion are converted again from their original, once per
    /// version of the converter. Text corrected by the user is never touched.
    func refreshEmailBodies() async {
        let key = "email_body_format"
        let version = "3"
        guard (try? archive.setting(key)) != version else { return }
        let archive = self.archive
        let changed =
            (try? await background { () -> Int in
                var changed = 0
                for item in try archive.items() where item.type == .email {
                    guard
                        let original = try archive.assets(itemID: item.id).first(where: { $0.kind == .originalEmail }),
                        let message = try? EmailParser.parse(archive.readAssetData(original))
                    else { continue }
                    if try archive.refreshEmailBody(itemID: item.id, body: message.bodyMarkdown) { changed += 1 }
                }
                try archive.setSetting(key, version)
                return changed
            }) ?? 0
        logger.notice("Email bodies converted again: \(changed)")
    }

    /// Creates the email item and, for each chosen attachment, a linked document (FR-184), all in the project.
    func importEmail(_ draft: EmailImportDraft) async throws -> Item {
        let archive = self.archive
        let scratch = paths.scratch
        let message = draft.message
        let input = EmailInput(
            from: message.from.map { EmailMeta.Address(name: $0.name, address: $0.address) },
            to: message.to.map { EmailMeta.Address(name: $0.name, address: $0.address) },
            cc: message.cc.map { EmailMeta.Address(name: $0.name, address: $0.address) }, subject: message.subject,
            sentAt: message.date, messageID: message.messageID, inReplyTo: message.inReplyTo,
            references: message.references, bodyMarkdown: message.bodyMarkdown, direction: draft.direction)
        let original = draft.original
        let projectID = draft.projectID
        let streamIDs = draft.streamIDs
        let attachments = draft.selected.sorted().compactMap { index in
            message.attachments.indices.contains(index) ? message.attachments[index] : nil
        }
        return try await background {
            let email = try archive.importEmail(input, original: original)
            if let projectID {
                try archive.updateItem(email.id) { $0.projectId = projectID }
                if !streamIDs.isEmpty { try archive.setStreams(streamIDs, itemID: email.id) }
            }
            for attachment in attachments {
                let folder = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: folder) }
                let name = attachment.filename.replacingOccurrences(of: "/", with: "-")
                let file = folder.appendingPathComponent(name)
                try attachment.data.write(to: file)
                let markdown = (try? ContentExtractor.extract(file).markdown) ?? ""
                let isImage = attachment.mimeType.hasPrefix("image/")
                let document = try archive.importDocument(
                    file, isImage: isImage, markdown: markdown,
                    title: (name as NSString).deletingPathExtension, occurredAt: email.occurredAt)
                if let projectID { try archive.updateItem(document.id) { $0.projectId = projectID } }
                try archive.addLink(from: document.id, to: email.id, kind: .attachmentOf, origin: .attachment)
            }
            return email
        }
    }

    /// "Nuova email" (pasted text or screenshot, FR-180.1/3).
    func createEmail(_ input: EmailInput, projectID: String?) async throws -> Item {
        let archive = self.archive
        return try await background {
            let email = try archive.importEmail(input, original: nil)
            if let projectID { try archive.updateItem(email.id) { $0.projectId = projectID } }
            return email
        }
    }

    static let searchIndexVersionKey = "search_index_version"

    /// Builds the search index over the existing archive once (ADR-0036), in the background.
    func buildSearchIndexIfNeeded() async {
        let archive = self.archive
        guard (try? archive.setting(Self.searchIndexVersionKey)) != "1" else { return }
        do {
            let count = try await background { try archive.rebuildSearchIndex() }
            try archive.setSetting(Self.searchIndexVersionKey, "1")
            logger.notice("Search index built: \(count) items")
        } catch {
            logger.error("Search index build failed: \(error)")
        }
    }

    /// Deletes for good what has been in the trash for 30 days (ADR-0030).
    func purgeExpiredTrash() async {
        let archive = self.archive
        do {
            let count = try await background { try archive.purgeExpiredTrash() }
            if count > 0 { logger.notice("Purged \(count) expired trash entries") }
        } catch {
            logger.error("Trash purge failed: \(error)")
        }
    }
}
