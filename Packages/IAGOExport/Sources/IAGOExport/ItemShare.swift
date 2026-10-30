import Foundation
import IAGOCore
import IAGOStore

/// «Condividi…» on an item (ADR-0080): the parts the user picks, written in clear to a folder, for the macOS Share
/// menu or a folder of the user's choice. Voice prints are not assets and never leave (ADR-0073).
public enum ItemShare {
    public enum Part: String, CaseIterable, Sendable, Hashable {
        /// Markdown with the facts, the summary, the key points and the notes.
        case card
        /// The main transcript (calls) or the text (emails, documents), as Markdown.
        case transcript
        /// The call's other transcript (ADR-0078).
        case otherTranscript
        /// The audio to listen to: the mix, or the imported file.
        case audio
        /// The microphone and system tracks, separately.
        case tracks
        /// The original file: email (.eml), document, image or Teams transcript.
        case original
        case screenshots
    }

    /// The parts this item has, in the order the sheet shows them.
    public static func available(_ itemID: String, archive: Archive) throws -> [Part] {
        guard let item = try archive.item(itemID) else { return [] }
        let kinds = Set(try archive.assets(itemID: itemID).map(\.kind))
        var parts: [Part] = [.card]
        if kinds.contains(.transcriptJSON) || (item.type != .call && kinds.contains(.contentMD)) {
            parts.append(.transcript)
        }
        if kinds.contains(.alternateTranscriptJSON) { parts.append(.otherTranscript) }
        if kinds.contains(.audioMix) || kinds.contains(.audioImport) { parts.append(.audio) }
        if kinds.contains(.audioMic), kinds.contains(.audioSystem) { parts.append(.tracks) }
        if !kinds.isDisjoint(with: originalKinds) { parts.append(.original) }
        if kinds.contains(.screenshot) { parts.append(.screenshots) }
        return parts
    }

    static let originalKinds: Set<Asset.Kind> = [
        .originalEmail, .originalDocument, .originalImage, .originalTranscript,
    ]

    /// The assets behind a part, to show their size before sharing.
    public static func assets(_ part: Part, itemID: String, archive: Archive) throws -> [Asset] {
        let assets = try archive.assets(itemID: itemID)
        switch part {
        case .card, .transcript, .otherTranscript: return []
        case .audio: return Array(assets.filter { $0.kind == .audioMix || $0.kind == .audioImport }.prefix(1))
        case .tracks: return assets.filter { $0.kind == .audioMic || $0.kind == .audioSystem }
        case .original: return assets.filter { originalKinds.contains($0.kind) }
        case .screenshots: return assets.filter { $0.kind == .screenshot }
        }
    }

    /// Writes the parts into `folder` (created if needed) and returns the files, in the order of `Part`.
    public static func write(
        _ parts: Set<Part>, itemID: String, archive: Archive, to folder: URL, timeZone: TimeZone = .current
    ) throws -> [URL] {
        guard let item = try archive.item(itemID) else { throw ArchiveError.notFound(itemID) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let base = baseName(item, timeZone: timeZone)
        var files: [URL] = []
        func text(_ markdown: String, _ name: String) throws {
            let url = folder.appendingPathComponent(name)
            try Data(markdown.utf8).write(to: url)
            files.append(url)
        }
        func asset(_ asset: Asset, _ name: String) throws {
            let url = folder.appendingPathComponent(name)
            _ = try archive.readAsset(asset, to: url)
            files.append(url)
        }
        for part in Part.allCases where parts.contains(part) {
            switch part {
            case .card:
                try text(try cardMarkdown(itemID, archive: archive, timeZone: timeZone), "\(base).md")
            case .transcript:
                if let markdown = try transcriptMarkdown(itemID, alternate: false, archive: archive) {
                    try text(markdown, "\(base) - \(String(localized: "trascrizione")).md")
                }
            case .otherTranscript:
                if let markdown = try transcriptMarkdown(itemID, alternate: true, archive: archive) {
                    try text(markdown, "\(base) - \(String(localized: "altra trascrizione")).md")
                }
            case .audio:
                for audio in try assets(.audio, itemID: itemID, archive: archive) { try asset(audio, "\(base).m4a") }
            case .tracks:
                for track in try assets(.tracks, itemID: itemID, archive: archive) {
                    let name =
                        track.kind == .audioMic ? String(localized: "microfono") : String(localized: "sistema")
                    try asset(track, "\(base) - \(name).m4a")
                }
            case .original:
                for original in try assets(.original, itemID: itemID, archive: archive) {
                    try asset(original, safe(original.originalName ?? "\(base).\(fileExtension(original.kind))"))
                }
            case .screenshots:
                for shot in try assets(.screenshots, itemID: itemID, archive: archive) {
                    let minute = shot.atSec.map {
                        TranscriptRenderer.clock($0).replacingOccurrences(of: ":", with: "-")
                    }
                    try asset(shot, "\(base) - \(String(localized: "schermata")) \(minute ?? shot.id).png")
                }
            }
        }
        return files
    }

    /// The item at a glance: facts, summary, key points with their status, notes. No transcript: that is a part
    /// of its own.
    public static func cardMarkdown(_ itemID: String, archive: Archive, timeZone: TimeZone = .current) throws
        -> String
    {
        let document = try ItemDocument.load(itemID, from: archive)
        let item = document.item
        var lines = ["# \(item.title)", ""]
        var facts = [TranscriptRenderer.format(item.occurredAt, "yyyy-MM-dd HH:mm", timeZone)]
        if let project = document.projectName { facts.append("Progetto: \(project)") }
        if let category = document.categoryName { facts.append("Categoria: \(category)") }
        if let duration = item.durationSec { facts.append("Durata: \(TranscriptRenderer.minutes(duration))") }
        if !document.participants.isEmpty {
            facts.append("Partecipanti: \(document.participants.joined(separator: ", "))")
        }
        if !document.attendees.isEmpty { facts.append("Presenti: \(document.attendees.joined(separator: ", "))") }
        if !document.tags.isEmpty { facts.append("Tag: \(document.tags.joined(separator: ", "))") }
        lines += [facts.joined(separator: " · "), ""]
        if let summary = document.summary {
            lines += ["## Sintesi", "", ItemDocument.plainSummary(summary, headingLevel: 3), ""]
        }
        let keyPoints = try archive.decisions(sourceItemID: itemID).filter { $0.decision.deletedAt == nil }
        if !keyPoints.isEmpty {
            lines += ["## Punti chiave", ""]
            for summary in keyPoints.sorted(by: { $0.decision.decidedAt < $1.decision.decidedAt }) {
                lines += ProjectExporter.decisionLines(summary, timeZone: timeZone)
            }
            lines.append("")
        }
        if !document.notes.isEmpty {
            lines += ["## Note"]
            for note in document.notes {
                lines += [
                    "",
                    "**\(TranscriptRenderer.format(note.notedAt, "yyyy-MM-dd HH:mm", timeZone)) · \(TranscriptRenderer.kindLabel(note.kind))**",
                    note.body,
                ]
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// A transcript with the speakers' names, or the text of an email or document.
    static func transcriptMarkdown(_ itemID: String, alternate: Bool, archive: Archive) throws -> String? {
        let document = try ItemDocument.load(itemID, from: archive)
        let assets = try archive.assets(itemID: itemID)
        if let json = assets.first(where: { $0.kind == (alternate ? .alternateTranscriptJSON : .transcriptJSON) }) {
            let transcript = try Transcript.decode(from: archive.readAssetData(json))
            let source = transcript.isImported ? "Teams" : "IAGO"
            var labelled = document
            labelled.transcript = transcript
            let lines =
                ["# \(document.item.title)", "", "\(String(localized: "Trascrizione")) \(source)", ""]
                + transcript.segments.map {
                    "**[\(TranscriptRenderer.clock($0.start))] \(labelled.label(for: $0.speaker)):** \($0.text)"
                }
            return lines.joined(separator: "\n") + "\n"
        }
        guard !alternate, let content = assets.first(where: { $0.kind == .contentMD }) else { return nil }
        return String(decoding: try archive.readAssetData(content), as: UTF8.self)
    }

    /// The folder the parts are written to: the item's date and title.
    public static func folderName(_ item: Item, timeZone: TimeZone = .current) -> String {
        baseName(item, timeZone: timeZone)
    }

    /// The folder as one `.zip` next to it, with macOS's own `ditto` (no network, nothing installed).
    public static func zip(_ folder: URL) throws -> URL {
        let archive = folder.deletingLastPathComponent().appendingPathComponent("\(folder.lastPathComponent).zip")
        try? FileManager.default.removeItem(at: archive)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", folder.path, archive.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: archive.path])
        }
        return archive
    }

    /// `2026-10-30 1530 Titolo`, safe as a file name.
    static func baseName(_ item: Item, timeZone: TimeZone) -> String {
        safe("\(TranscriptRenderer.format(item.occurredAt, "yyyy-MM-dd HHmm", timeZone)) \(item.title)")
    }

    static func safe(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    static func fileExtension(_ kind: Asset.Kind) -> String {
        switch kind {
        case .originalEmail: "eml"
        case .originalImage: "png"
        case .originalTranscript: "vtt"
        default: "pdf"
        }
    }
}
