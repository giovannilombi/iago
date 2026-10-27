import Foundation
import GRDB

/// Screenshots of a call ("Segna momento con screenshot", ADR-0072): encrypted PNG files of the item, each with the
/// second of the call it was taken at and the text read on it. The text joins the call's search and the engine's input.
extension Archive {
    public static let screenshotLabel = "Schermata"
    /// Setting: Claude may also see the images of the screenshots, not only their text (ADR-0072).
    public static let shareScreenshotsWithClaudeKey = "claude.share_screenshots"

    @discardableResult
    public func addScreenshot(itemID: String, png: Data, atSec: Double, text: String?) throws -> Asset {
        let id = newID(at: writer.now)
        let relPath = "\(itemID)/screenshot-\(id).png.enc"
        let result = try EncryptedFile.encrypt(
            png, to: itemsRoot.appendingPathComponent(relPath), key: try itemKey(itemID), context: relPath)
        let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        // No orphan encrypted file if the database refuses the row.
        do {
            return try record(id: id, itemID: itemID, relPath: relPath, result: result, atSec: atSec, text: cleaned)
        } catch {
            try? FileManager.default.removeItem(at: itemsRoot.appendingPathComponent(relPath))
            throw error
        }
    }

    private func record(
        id: String, itemID: String, relPath: String, result: EncryptedFile.Result, atSec: Double, text cleaned: String?
    ) throws -> Asset {
        let writer = self.writer
        return try database.writer.write { db in
            var asset = Asset(id: id, itemId: itemID, kind: .screenshot, relPath: relPath)
            asset.sizeBytes = result.size
            asset.sha256 = result.sha256
            asset.atSec = atSec
            asset.text = cleaned?.isEmpty == false ? cleaned : nil
            asset.originalName = "\(Self.screenshotLabel) \(Self.clock(atSec)).png"
            try writer.save(&asset, db)
            let projectID = try String.fetchOne(
                db, sql: "SELECT project_id FROM item WHERE id = ?", arguments: [itemID])
            try Self.indexScreenshot(asset, projectID: projectID, db)
            return asset
        }
    }

    /// The screenshots of an item, in order of time.
    public func screenshots(itemID: String) throws -> [Asset] {
        try database.writer.read { db in
            try Asset.filter(
                Column("item_id") == itemID && Column("kind") == Asset.Kind.screenshot.rawValue
                    && Column("deleted_at") == nil && Column("trashed_at") == nil
            )
            .order(Column("at_sec")).fetchAll(db)
        }
    }

    public func deleteScreenshot(_ id: String) throws {
        let now = self.now()
        let writer = self.writer
        let relPath: String? = try database.writer.write { db in
            guard var asset = try Asset.fetchOne(db, key: id), asset.kind == .screenshot else { return nil }
            asset.deletedAt = now
            asset.text = nil
            asset.originalName = nil
            asset.sha256 = nil
            try writer.save(&asset, db)
            try db.execute(
                sql: "DELETE FROM search_index WHERE source_id = ?", arguments: ["\(asset.itemId)#shot-\(id)"])
            return asset.relPath
        }
        if let relPath { try? FileManager.default.removeItem(at: itemsRoot.appendingPathComponent(relPath)) }
    }

    static func indexScreenshot(_ asset: Asset, projectID: String?, _ db: Database) throws {
        guard let text = asset.text, !text.isEmpty else { return }
        try db.execute(
            sql:
                "INSERT INTO search_index (item_id, project_id, source, source_id, at_sec, text) VALUES (?, ?, 'transcript', ?, ?, ?)",
            arguments: [
                asset.itemId, projectID, "\(asset.itemId)#shot-\(asset.id)", asset.atSec,
                "\(screenshotLabel): \(text.replacingOccurrences(of: "\n", with: " · "))",
            ])
    }

    /// "12:40" or "1:02:05".
    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        let (hours, minutes, rest) = (total / 3600, (total % 3600) / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%02d:%02d", minutes, rest)
    }
}
