import Foundation
import IAGOCore

/// Moves a finalized recording (plaintext `mic.m4a`, `system.m4a`, `mix.m4a`, `session.json`) into the
/// encrypted archive as an `Unclassified` item (FR-17), then deletes the plaintext folder. Idempotent:
/// after a crash it is run again on the same folder and completes the missing steps. Phase 0 folders in
/// `Recordings/` have the same layout and go through the same path (ADR-0029).
public struct RecordingArchiver: Sendable {
    public let archive: Archive

    public init(archive: Archive) {
        self.archive = archive
    }

    static let tracks: [(file: String, kind: Asset.Kind)] = [
        ("mic.m4a", .audioMic), ("system.m4a", .audioSystem), ("mix.m4a", .audioMix),
    ]

    /// Folders under `root` that hold a finalized recording.
    public static func pendingFolders(in root: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return entries.filter { url in
            ItemID(rawValue: url.lastPathComponent) != nil
                && FileManager.default.fileExists(atPath: url.appendingPathComponent("session.json").path)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @discardableResult
    public func archive(folder: URL) throws -> Item {
        let manifest = try SessionManifest.decode(from: Data(contentsOf: folder.appendingPathComponent("session.json")))
        let id = manifest.itemID.rawValue

        var item = try archive.item(id)
        if item == nil {
            item = try archive.createItem(
                id: id,
                title: manifest.suggestedTitle.flatMap { $0.isEmpty ? nil : $0 }
                    ?? ItemTitle.unclassified(startedAt: manifest.startedAt), occurredAt: manifest.startedAt,
                source: .recording, status: .recorded, durationSec: manifest.duration,
                captureMeta: try Self.captureMeta(manifest))
        }
        if try archive.markers(itemID: id).isEmpty {
            for marker in manifest.markers where marker.kind == .bookmark {
                try archive.addMarker(itemID: id, atSec: marker.at, note: marker.detail)
            }
        }
        // Screenshots (ADR-0072): each file goes into the archive and then away; after a crash the ones left are added.
        for marker in manifest.markers where marker.kind == .screenshot {
            guard let name = marker.detail else { continue }
            let file = folder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            let sidecar = file.deletingPathExtension().appendingPathExtension("txt")
            let text = try? String(contentsOf: sidecar, encoding: .utf8)
            try archive.addScreenshot(itemID: id, png: Data(contentsOf: file), atSec: marker.at, text: text)
            try FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: sidecar)
        }
        for track in Self.tracks {
            let file = folder.appendingPathComponent(track.file)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            try archive.storeAsset(file, itemID: id, kind: track.kind, fileName: track.file)
            try FileManager.default.removeItem(at: file)
        }
        try FileManager.default.removeItem(at: folder)
        return item!
    }

    /// `item.capture_meta`: pauses, device changes and devices used (spec 8.2). Bookmarks live in `marker`.
    static func captureMeta(_ manifest: SessionManifest) throws -> String {
        struct Meta: Encodable {
            var markers: [CaptureMarker]
            var devices: [TrackKind: [String]]
            var sampleRate: Double
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let meta = Meta(
            markers: manifest.markers.filter { $0.kind != .bookmark && $0.kind != .screenshot },
            devices: manifest.devices,
            sampleRate: manifest.sampleRate)
        return String(decoding: try encoder.encode(meta), as: UTF8.self)
    }
}

extension Archive {
    /// Imports a document or image as "material to classify" (spec 3.20, brought forward): the original
    /// (encrypted) and its Markdown. `markdown` comes from the extractor (IAGOIngest).
    @discardableResult
    public func importDocument(
        _ original: URL, isImage: Bool, markdown: String, title: String, occurredAt: Date
    ) throws -> Item {
        let item = try createItem(
            type: .document, title: title, occurredAt: occurredAt, source: .import, status: .ready)
        do {
            let name = original.lastPathComponent
            try storeAsset(
                original, itemID: item.id, kind: isImage ? .originalImage : .originalDocument,
                fileName: "original.\(original.pathExtension.lowercased())", originalName: name)
            try storeAsset(Data(markdown.utf8), itemID: item.id, kind: .contentMD, fileName: "content.md")
            try indexDocument(markdown, itemID: item.id)
        } catch {
            try? purgeItem(item.id)
            throw error
        }
        return item
    }

    /// Attaches an imported transcript (e.g. Teams) to an item (ADR-0033): it becomes the item's
    /// transcript; the original file is kept as well. TXT and MD are rendered by the caller.
    public func attachImportedTranscript(
        _ transcriptJSON: Data, speakers: [(id: String, label: String)], original: URL, to itemID: String
    ) throws {
        try storeAsset(
            original, itemID: itemID, kind: .originalTranscript,
            fileName: "original-transcript.\(original.pathExtension.lowercased())",
            originalName: original.lastPathComponent)
        try storeAsset(transcriptJSON, itemID: itemID, kind: .transcriptJSON, fileName: "transcript.json")
        try setSpeakers(speakers, for: itemID)
        try updateItem(itemID) { $0.status = .transcribed }
    }

    /// Creates an imported item (FR-30, FR-31) from an audio file already converted to m4a. The file
    /// is encrypted as the single `audio_import` track; the caller deletes the converted copy.
    @discardableResult
    /// FR-191: the user corrects the Markdown of a document or email. The automatic version is kept the first
    /// time, so it can always be restored; search follows the corrected text.
    public func updateContentMarkdown(_ markdown: String, itemID: String) throws {
        let assets = try assets(itemID: itemID)
        if !assets.contains(where: { $0.kind == .contentMDAuto }),
            let current = assets.first(where: { $0.kind == .contentMD })
        {
            try storeAsset(
                try readAssetData(current), itemID: itemID, kind: .contentMDAuto, fileName: "content-auto.md")
        }
        try storeAsset(Data(markdown.utf8), itemID: itemID, kind: .contentMD, fileName: "content.md")
        try indexDocument(markdown, itemID: itemID)
    }

    /// Back to the extracted text; the corrected one is replaced.
    public func restoreAutomaticMarkdown(itemID: String) throws {
        guard let auto = try assets(itemID: itemID).first(where: { $0.kind == .contentMDAuto }) else { return }
        let markdown = String(decoding: try readAssetData(auto), as: UTF8.self)
        try storeAsset(Data(markdown.utf8), itemID: itemID, kind: .contentMD, fileName: "content.md")
        try purgeAsset(auto.id)
        try indexDocument(markdown, itemID: itemID)
    }

    public func importAudio(_ converted: URL, title: String, occurredAt: Date, durationSec: Double?) throws -> Item {
        let item = try createItem(
            title: title, occurredAt: occurredAt, source: .import, status: .recorded, durationSec: durationSec)
        do {
            try storeAsset(converted, itemID: item.id, kind: .audioImport, fileName: "import.m4a")
        } catch {
            try? purgeItem(item.id)
            throw error
        }
        return item
    }
}
