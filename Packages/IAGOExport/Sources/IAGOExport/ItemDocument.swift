import Foundation
import IAGOCore
import IAGOStore

/// Everything needed to render one item (spec 11.1, 11.3). Speaker names come from `item_speaker`
/// (renames never rewrite `transcript.json`, spec 7.3).
public struct ItemDocument: Sendable {
    public var item: Item
    public var projectName: String?
    public var categoryName: String?
    public var tags: [String]
    /// Speaker ID → label chosen by the user; falls back to the transcript labels.
    public var speakerLabels: [String: String]
    public var notes: [Note]
    public var transcript: Transcript?
    /// The summary written with the category's template (ADR-0054), as plain Markdown (no app links).
    public var summary: String?

    public init(
        item: Item, projectName: String? = nil, categoryName: String? = nil, tags: [String] = [],
        speakerLabels: [String: String] = [:], notes: [Note] = [], transcript: Transcript? = nil, summary: String? = nil
    ) {
        self.summary = summary
        self.item = item
        self.projectName = projectName
        self.categoryName = categoryName
        self.tags = tags
        self.speakerLabels = speakerLabels
        self.notes = notes
        self.transcript = transcript
    }

    /// Reads the item, its metadata and (decrypting it) its transcript from the archive.
    public static func load(_ itemID: String, from archive: Archive, transcript: Transcript? = nil) throws
        -> ItemDocument
    {
        guard let item = try archive.item(itemID) else { throw ArchiveError.notFound(itemID) }
        var loaded = transcript
        if loaded == nil, let asset = try archive.assets(itemID: itemID).first(where: { $0.kind == .transcriptJSON }) {
            loaded = try Transcript.decode(from: archive.readAssetData(asset))
        }
        return ItemDocument(
            item: item,
            projectName: try item.projectId.flatMap { id in
                try archive.projects(includeArchived: true).first { $0.id == id }?.name
            },
            categoryName: try item.categoryId.flatMap { id in
                try archive.categories(includeArchived: true).first { $0.id == id }?.name
            },
            tags: try archive.tags(for: itemID).map(\.name),
            speakerLabels: Dictionary(
                uniqueKeysWithValues: try archive.speakers(itemID: itemID).map { ($0.speakerId, $0.label) }),
            notes: try archive.notes(itemID: itemID),
            transcript: loaded, summary: try archive.summary(itemID: itemID).map { Self.plainSummary($0.markdown) })
    }

    /// The summary for files: minutes without the app link, headings one level down (`##` → `level`).
    public static func plainSummary(_ markdown: String, headingLevel: Int = 2) -> String {
        let unlinked = markdown.replacing(/\[(\d{2,}:\d{2})\]\(iago:\/\/seek\/\d+\)/) { "[\($0.1)]" }
        guard headingLevel != 2 else { return unlinked }
        let hashes = String(repeating: "#", count: headingLevel)
        return unlinked.components(separatedBy: "\n").map { line in
            line.hasPrefix("## ") ? hashes + " " + line.dropFirst(3) : line
        }.joined(separator: "\n")
    }

    public func label(for speakerID: String) -> String {
        speakerLabels[speakerID] ?? transcript?.speakers.first { $0.id == speakerID }?.label ?? speakerID
    }

    /// Speakers in order of first appearance.
    public var participants: [String] {
        guard let transcript else { return [] }
        var seen: [String] = []
        for segment in transcript.segments where !seen.contains(segment.speaker) { seen.append(segment.speaker) }
        return seen.map(label(for:))
    }
}
